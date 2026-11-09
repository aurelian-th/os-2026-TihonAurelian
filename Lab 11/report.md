# Operating Systems — Laboratory Work No. 11: The Race and the Semaphore (Linux)

**Course:** Operating Systems  
**Institution:** Technical University of Moldova (UTM), FCIM, FAF  
**Student:** Tihon Aurelian-Mihai  
**Group:** FAF-241  
**Supervisor:** univ. assist. Patricia Reițman  

---

## Part 1: Observing the Race Condition (`race.c`)

### Source Implementation
The program `race.c` spawns two concurrent POSIX threads (`pthread_create`), each executing a loop of $N = 1\,000\,000$ increment operations on a shared global variable `counter` without synchronization:

```c
#include <stdio.h>
#include <pthread.h>

#define N 1000000

long counter = 0; /* shared by both threads */

void *add(void *arg) {
    (void)arg;
    for (int i = 0; i < N; i++)
        counter++; /* read, add 1, write back: three steps */
    return NULL;
}

int main(void) {
    pthread_t a, b;
    pthread_create(&a, NULL, add, NULL);
    pthread_create(&b, NULL, add, NULL);
    pthread_join(a, NULL);
    pthread_join(b, NULL);
    printf("counter = %ld (expected %d)\n", counter, 2 * N);
    return 0;
}
```

### Execution Outputs
Compiled without compiler optimizations (`gcc -Wall -pthread -o race race.c`) to preserve memory access instructions:
```text
$ ./race
counter = 1000000 (expected 2000000)
$ ./race
counter = 1135215 (expected 2000000)
$ ./race
counter = 1049623 (expected 2000000)
```

### Observations and Analysis
1. **counter++ looks like one step. Write the three steps the CPU really does.**  
   At the machine instruction level on the x86-64 architecture, the high-level C statement `counter++` decomposes into three distinct CPU operations:
   - **Load:** The CPU reads the value of `counter` from RAM/cache into a general-purpose processor register (e.g. `movq counter(%rip), %rax`).
   - **Add:** The arithmetic logic unit increments the register value by 1 (`addq $1, %rax`).
   - **Store:** The CPU writes the incremented value from the register back to the memory location of `counter` (`movq %rax, counter(%rip)`).

2. **Describe, with those steps, how two threads can lose one addition.**  
   Suppose `counter` holds the value 50. Thread A executes the **Load** step and reads 50 into its local register `%rax_A`. Before Thread A executes the Store step, the operating system kernel scheduler preempts Thread A or Thread B runs concurrently on an adjacent CPU core. Thread B executes the **Load** step and reads 50 into `%rax_B`. Thread B executes **Add** (`%rax_B = 51`) and **Store** (`counter = 51`). When Thread A resumes execution, it continues with its stale register value (`%rax_A = 50`), performs its **Add** (`%rax_A = 51`), and performs its **Store** (`counter = 51`). Despite two distinct increment operations having occurred across both threads, `counter` advanced by only 1, completely losing one addition.

3. **Why is the result different at every run?**  
   The final value depends on non-deterministic thread interleavings governed by OS preemptive scheduling, hardware cache coherence line transitions, timer interrupts, and system load. The exact points at which threads collide in memory vary dynamically during each execution cycle.

---

## Part 2: Critical Section Protection via Mutex and Semaphore

### 2.1 Mutex Implementation (`mutex.c`)
A mutual exclusion lock (`pthread_mutex_t`) guarantees that only a single thread can execute the critical section at any given instant:
```c
pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;

void *add(void *arg) {
    (void)arg;
    for (int i = 0; i < N; i++) {
        pthread_mutex_lock(&lock);
        counter++;
        pthread_mutex_unlock(&lock);
    }
    return NULL;
}
```

### 2.2 Counting Semaphore as a Binary Lock (`sem.c`)
A POSIX counting semaphore initialized to 1 (`sem_init(&s, 0, 1)`) functions as a binary mutual exclusion lock:
```c
sem_t s;

void *add(void *arg) {
    (void)arg;
    for (int i = 0; i < N; i++) {
        sem_wait(&s);
        counter++;
        sem_post(&s);
    }
    return NULL;
}
```

### Execution Outputs
Both synchronized implementations produce deterministic, mathematically correct results:
```text
$ ./mutex
counter = 2000000 (expected 2000000)

$ ./sem
counter = 2000000 (expected 2000000)
```

### 2.3 Benchmark Performance Comparison
Timing comparison measured via `time`:
```text
$ time ./race
real    0m0.005s    user 0m0.008s    sys 0m0.000s

$ time ./mutex
real    0m0.098s    user 0m0.126s    sys 0m0.064s

$ time ./sem
real    0m0.224s    user 0m0.208s    sys 0m0.207s
```

### Observations and Analysis
1. **Is the answer always 2 000 000 now?**  
   Yes. Both `mutex` and `sem` enforce mutual exclusion, guaranteeing that every single increment executes as an isolated critical section.
2. **Which is faster: mutex or semaphore? Why?**  
   The `mutex` is substantially faster than the `semaphore` (0.098 s versus 0.224 s). Modern Linux `pthread_mutex` implementations utilize `futex` (Fast Userspace Mutex) primitives: when there is no lock contention, acquiring and releasing a mutex occurs entirely within user space via atomic compare-and-swap instructions without invoking kernel traps. POSIX semaphores (`sem_wait` / `sem_post`) have slightly higher call overhead and context management abstractions.

---

## Part 3: Semaphore as a Signal (`order.c`)

### Source Implementation
A semaphore initialized to 0 (`sem_init(&ready, 0, 0)`) enforces deterministic sequencing across asynchronous threads. Reader thread B starts first but blocks in `sem_wait(&ready)` until writer thread A completes its work and issues `sem_post(&ready)`:
```c
char message[32];
sem_t ready; /* starts at 0 */

void *writer(void *arg) {
    (void)arg;
    sleep(1);
    strcpy(message, "hello");
    printf("A: message written\n");
    sem_post(&ready); /* 0 -> 1: unblocks B */
    return NULL;
}

void *reader(void *arg) {
    (void)arg;
    printf("B: waiting for the message...\n");
    sem_wait(&ready); /* blocks while value == 0 */
    printf("B: I read \"%s\"\n", message);
    return NULL;
}
```

### Execution Output
```text
$ ./order
B: waiting for the message...
A: message written
B: I read "hello"
```

### Observations and Analysis
1. **Change the start value to 1 (`sem_init(&ready, 0, 1)`). What does B read now, and why?**  
   When initialized to 1, `sem_wait(&ready)` in thread B immediately decrements the semaphore from 1 to 0 and proceeds without blocking. Because thread A is sleeping (`sleep(1)`), thread B accesses `message` before thread A writes `"hello"`, outputting `B: I read ""`. This proves that initializing to 0 is mandatory when a semaphore is used to signal the completion of an event.
2. **In one sentence: what does a semaphore that starts at 0 mean?**  
   A semaphore initialized to 0 represents an event signaling dependency where consuming threads must suspend execution until a producing thread explicitly signals that the required condition or data is ready.

---

## Part 4: Semaphore as a Resource Counter (`parking.c`)

### Source Implementation
A counting semaphore initialized to `PLACES = 3` manages shared finite capacity for 6 concurrent car threads:
```c
#define PLACES 3
#define CARS   6

sem_t places;
pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
int inside = 0;

void *car(void *arg) {
    long id = (long)arg;
    sem_wait(&places); /* acquire permit */
    pthread_mutex_lock(&lock);
    inside++;
    printf("car %ld enters (inside: %d)\n", id, inside);
    pthread_mutex_unlock(&lock);

    sleep(1);

    pthread_mutex_lock(&lock);
    inside--;
    printf("car %ld leaves (inside: %d)\n", id, inside);
    pthread_mutex_unlock(&lock);
    sem_post(&places); /* release permit */
    return NULL;
}
```

### Execution Output
```text
$ ./parking
car 1 enters (inside: 1)
car 2 enters (inside: 2)
car 3 enters (inside: 3)
car 1 leaves (inside: 2)
car 3 leaves (inside: 1)
car 2 leaves (inside: 0)
car 5 enters (inside: 1)
car 6 enters (inside: 2)
car 4 enters (inside: 3)
car 5 leaves (inside: 2)
car 4 leaves (inside: 1)
car 6 leaves (inside: 0)
```

### Observations and Analysis
1. **What is the largest value of "inside" you see? Which line of code guarantees it?**  
   The largest observed value is **3**. This invariant is strictly guaranteed by `sem_wait(&places);` because `places` was initialized with capacity 3 via `sem_init(&places, 0, PLACES);`. Once 3 threads pass `sem_wait`, the semaphore counter reaches 0, forcing subsequent threads into a blocking wait queue until an active car calls `sem_post(&places);`.
2. **Set PLACES to 1. What does the semaphore become?**  
   When initialized with capacity 1, the counting semaphore degenerates into a **binary semaphore**, functioning as a mutual exclusion lock where at most one vehicle can occupy the parking structure at any moment.

---

## Optional: Lock-Free Synchronization via Atomic Operations (`atomic.c`)

### Implementation & Performance
Using `<stdatomic.h>`, `atomic_fetch_add(&counter, 1)` translates into hardware-locked atomic bus operations (e.g. `lock incq counter(%rip)` on x86-64), ensuring indivisibility without mutex or semaphore lock overhead:
```c
#include <stdatomic.h>

atomic_long counter = 0;

void *add(void *arg) {
    (void)arg;
    for (int i = 0; i < N; i++)
        atomic_fetch_add(&counter, 1);
    return NULL;
}
```

```text
$ time ./atomic
counter = 2000000 (expected 2000000)
real    0m0.031s    user 0m0.060s    sys 0m0.001s
```
Atomic execution is over 3 times faster than mutex synchronization and 7 times faster than semaphore operations while guaranteeing complete mathematical correctness.

