# Laboratory Work No. 12: Producer, Consumer and the Other Tools

Course: Operating Systems  
Student: Tihon Aurelian-Mihai  
Group: FAF-241  
Supervisor: univ. assist. Patricia Reițman  

---

## Part 1: Producer and Consumer

### Source implementation
The program `prodcons.c` coordinates a fast producer and a slow consumer accessing a circular bounded buffer of 4 slots. Synchronization is managed through three primitives:
- `sem_t empty`: initialized to `SIZE` (4), tracking available buffer capacity.
- `sem_t full`: initialized to 0, tracking the count of unconsumed items.
- `pthread_mutex_t lock`: mutual exclusion lock guarding buffer mutations.

### Observations and analysis

#### 1. The producer is fast, yet "in buffer" never goes above 4. Which call stops it?
The call that stops the producer is:
```c
sem_wait(&empty);
```
At program startup, `empty` is initialized to 4. As the fast producer iterates, it decrements `empty` on each insertion. Because the consumer sleeps for 300 ms between removals, the producer rapidly deposits 4 items, driving `empty` down to 0. When attempting to insert the 5th item, `sem_wait(&empty)` detects a counter value of zero and suspends the producer thread in the kernel until the consumer finishes processing an item and calls `sem_post(&empty)`.

#### 2. Who waits at the start: the consumer or the producer? Which call makes it wait?
The consumer waits at startup. The call that forces it to wait is:
```c
sem_wait(&full);
```
At initialization, `full` is set to 0 because the buffer is empty. When the consumer starts execution, its first action is `sem_wait(&full)`. Because the counter is zero, the consumer immediately blocks and yields the CPU until the producer writes the first item and signals `sem_post(&full)`.

#### 3. Swapping lock acquisition before `sem_wait(&empty)`
When the first two lines of `producer()` are swapped such that the mutex is acquired before the semaphore:
```c
pthread_mutex_lock(&lock);
sem_wait(&empty);
```
The program deadlocks once the buffer fills to 4 items. The producer acquires `lock`, inserts 4 items, and upon reaching the 5th iteration, enters `sem_wait(&empty)` while still holding `lock`. The producer blocks waiting for an empty slot. When the consumer attempts to consume an item, it calls `pthread_mutex_lock(&lock)` to enter the critical section, but blocks because the producer holds the mutex. Consequently, both threads become permanently blocked: the producer holds the mutex and waits for the semaphore, while the consumer holds neither and waits for the mutex. The program hangs indefinitely until terminated with `SIGKILL` or timeout (exit code 124).

---

## Part 2: The Condition Variable

### Source implementation
The program `condvar.c` resolves the execution ordering problem between writer thread A and reader thread B using a mutex `lock`, a condition variable `changed`, and a state predicate variable `ready`.

### Observations and analysis

#### 1. In `order.c` (Lab 11) the semaphore itself remembered that the message was ready. Here, which variable remembers it?
The integer state variable `ready` (initialized to 0 and set to 1 by thread A) remembers the state:
```c
int ready = 0;
```
A condition variable possesses no internal memory or counter; it is merely an execution wait queue. The actual state must always be explicitly stored in an ordinary program variable protected by the associated mutex.

#### 2. Replacing `while (!ready)` with `if (!ready)`
When `while (!ready)` is replaced with `if (!ready)`, the program compiles and executes correctly in this specific single-producer, single-consumer scenario:
```c
B: not ready, I sleep
A: message written
B: I read "hello"
```
Because there is only one reader thread and no intervening state mutations, the condition remains true when thread B is awakened.

#### 3. Justification for `while` loops over `if` statements
The `while` loop construct is mandatory in robust concurrent software for two fundamental reasons:
1. Spurious wakeups: Under POSIX and Linux kernel futex semantics, a thread waiting on `pthread_cond_wait()` may be awakened without an explicit signal or broadcast (for example, due to OS signal delivery or internal context switch optimizations). Re-checking `ready` inside a `while` loop ensures that if the thread wakes up spuriously while `ready == 0`, it immediately re-enters sleep.
2. Competing consumer threads: In applications with multiple consumers, waking threads contend for the mutex. The first thread to acquire the lock may consume the resource and reset `ready = 0`. If subsequent threads were awakened with an `if` statement, they would proceed to execute with invalid state assumptions instead of re-evaluating the predicate.

---

## Part 3: Readers and Writers

### Source implementation
The program `readers.c` implements the first readers-writers problem (reader-preference) using two semaphores:
- `sem_t room`: binary semaphore (starts at 1) granting exclusive writing access to the shared room.
- `sem_t rlock`: binary semaphore (starts at 1) providing mutual exclusion when updating the active reader count `readers`.

### Observations and analysis

#### 1. Permitting concurrent readers while isolating writers
The two lines within `reader()` that coordinate this behavior are:
```c
if (++readers == 1)
    sem_wait(&room);
```
and
```c
if (--readers == 0)
    sem_post(&room);
```
When the first reader arrives (`++readers == 1`), it claims exclusive ownership of `room`, preventing any writer from entering. Subsequent readers increment the counter and enter immediately without waiting on `room`. When readers depart, the last reader (`--readers == 0`) releases `room`, allowing waiting writers to proceed.

#### 2. Necessity of `rlock` protecting `readers`
The integer variable `readers` is a shared global memory counter manipulated by concurrent reader threads. Increment operations (`++readers`) and decrement operations (`--readers`) decompose into non-atomic load-modify-store CPU instructions. Without `rlock`, concurrent readers would experience race conditions:
- Two readers could simultaneously execute `++readers`, resulting in a lost count or both observing `readers == 1`, leading to invalid double waits on `room`.
- Two readers departing simultaneously could corrupt the decrement, causing `readers` to never reach zero (permanently locking out writers) or reaching zero prematurely while readers remain active.

#### 3. Writer starvation under sustained reader traffic
If new reader threads arrive continuously without pause, writer 2 experiences starvation (indefinite postponement). Because the first reader locks `room` and subsequent readers bypass `room` while `readers > 0`, the condition `--readers == 0` is never satisfied. As long as at least one reader remains active, writers remain blocked on `sem_wait(&room)` indefinitely.

---

## Part 4: Deadlock Construction and Resolution

### Source implementation
The program `deadlock.c` models two concurrent threads attempting to acquire two shared mutex locks `A` and `B`.

### Observations and analysis

#### 1. Lock allocation graph and dependency cycle
In the deadlocked run, the state of threads and locks is as follows:
- Thread `one` acquires mutex `A` and blocks waiting to acquire mutex `B`.
- Thread `two` acquires mutex `B` and blocks waiting to acquire mutex `A`.

The circular wait dependency graph is:
```
Thread one ---> Mutex B ---> Thread two ---> Mutex A ---> Thread one
```
Both threads satisfy Coffman's four deadlock conditions: mutual exclusion, hold and wait, no preemption, and circular wait.

#### 2. Removing `sleep(1)` from the uncoordinated implementation
When both `sleep(1)` invocations are removed from the inverted lock acquisition code and executed across 10 iterations:
- Several iterations complete successfully (`exit code 0`), while others hang indefinitely (`exit code 124`).
- Intermittent failure occurs because execution depends entirely on whether thread `one` finishes both lock acquisitions before thread `two` is scheduled.
- This behavior is significantly worse than a consistent failure because it transforms a deterministic, easily detectable deadlock into a latent Heisenbug that evades development testing and triggers unpredictably under production concurrency loads.

#### 3. Lock ordering guarantee
Enforcing a globally consistent lock acquisition order prevents deadlock because all threads acquire resources along a directed acyclic graph, making circular wait mathematically impossible.

