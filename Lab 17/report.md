# Operating Systems — Laboratory Work No. 17: Threads Share Memory, and Race (Linux)

**Course:** Operating Systems  
**Institution:** Technical University of Moldova (UTM), FCIM, FAF  
**Student:** Tihon Aurelian-Mihai  
**Group:** FAF-241  
**Supervisor:** univ. assist. Patricia Reițman  

---

## Part 1: Shared and Racing (2 Threads)

### Source Implementation
In Part 1, two POSIX threads share the global variable `counter` and each executes `counter++` $N = 1\,000\,000$ times without synchronization (`gcc -Wall -Wextra -pthread -o fire fire.c`). At program start inside `work()`, each thread prints the current value of `counter`.

### Execution Outputs (2 Threads)
```text
$ gcc -Wall -Wextra -pthread -o fire fire.c
$ ./fire
thread 1 sees counter = 0
thread 2 sees counter = 0
expected: 2000000
counter: 1034471 (lost updates: the race)

$ ./fire
thread 2 sees counter = 0
thread 1 sees counter = 0
expected: 2000000
counter: 1044285 (lost updates: the race)

$ ./fire
thread 1 sees counter = 0
thread 2 sees counter = 2139
expected: 2000000
counter: 1300770 (lost updates: the race)

$ ./fire
thread 1 sees counter = 0
thread 2 sees counter = 0
expected: 2000000
counter: 1052441 (lost updates: the race)

$ ./fire
thread 1 sees counter = 0
thread 2 sees counter = 0
expected: 2000000
counter: 1328725 (lost updates: the race)
```

### Observe Answers (Part 1)

1. **Thread 2 prints a non-zero counter at the start. What does that prove about the memory of the two threads?**  
   When thread 2 prints `thread 2 sees counter = 2139`, it observes the updates already written by thread 1 immediately without any inter-process copy or pipe. This proves that threads belonging to the same process share a single virtual address space, including global variables in the `.bss`/`.data` segment and the heap (only each thread's registers and stack are private).

2. **Why is the final counter less than 2000000, and different each run? Explain with the three steps of `counter++`.**  
   In machine code (`objdump -d fire`), `counter++` compiles into three non-atomic CPU instructions: (1) **read** `counter` from memory into a register (`mov 0x2e25(%rip), %rax`), (2) **add** 1 to that register (`add $0x1, %rax`), and (3) **write** the register back to memory (`mov %rax, 0x2e1a(%rip)`). If thread 1 and thread 2 both read the same value (for example `50`) before either writes back, both add 1 to get `51` and both write `51` to `counter`, so two increments raise the counter by only 1 and one update is lost. Because OS thread scheduling, core timing, and cache coherence interleavings vary non-deterministically from run to run, the exact number of overlapping read-add-write windows changes every execution, producing a different total each time that is less than `2000000`.

---

## Part 2: Scaling to Four Threads (`fire.c`)

### Updated Source Implementation
Two additional threads (`c` and `d`) were added in `fire.c` (4 threads total, each performing $1\,000\,000$ increments, expected total $4\,000\,000$):

```c
/* fire.c - four threads of one process share the same memory.
 * All add to the same counter, a million times each, WITHOUT a lock.
 * Build: gcc -Wall -Wextra -pthread -o fire fire.c  Run: ./fire
 */
#include <stdio.h>
#include <pthread.h>

#define N 1000000
long counter = 0; /* one variable, shared by all threads */

void *work(void *arg) {
    long id = (long)arg;
    printf("thread %ld sees counter = %ld\n", id, counter);
    for (int i = 0; i < N; i++)
        counter++; /* NOT atomic: read, add, write */
    return NULL;
}

int main(void) {
    pthread_t a, b, c, d;
    pthread_create(&a, NULL, work, (void *)1);
    pthread_create(&b, NULL, work, (void *)2);
    pthread_create(&c, NULL, work, (void *)3);
    pthread_create(&d, NULL, work, (void *)4);
    pthread_join(a, NULL);
    pthread_join(b, NULL);
    pthread_join(c, NULL);
    pthread_join(d, NULL);
    printf("expected: %d\n", 4 * N);
    printf("counter: %ld (lost updates: the race)\n", counter);
    return 0;
}
```

### Execution Outputs (4 Threads)
```text
$ make
gcc -Wall -Wextra -pthread -o fire fire.c
$ ./fire
thread 1 sees counter = 0
thread 3 sees counter = 0
thread 4 sees counter = 0
thread 2 sees counter = 12240
expected: 4000000
counter: 1179230 (lost updates: the race)

$ ./fire
thread 2 sees counter = 0
thread 3 sees counter = 0
thread 1 sees counter = 0
thread 4 sees counter = 0
expected: 4000000
counter: 1514330 (lost updates: the race)

$ ./fire
thread 1 sees counter = 0
thread 3 sees counter = 0
thread 2 sees counter = 5045
thread 4 sees counter = 4616
expected: 4000000
counter: 1328062 (lost updates: the race)

$ ./fire
thread 1 sees counter = 0
thread 3 sees counter = 0
thread 2 sees counter = 0
thread 4 sees counter = 3206
expected: 4000000
counter: 1899933 (lost updates: the race)

$ ./fire
thread 1 sees counter = 0
thread 2 sees counter = 0
thread 4 sees counter = 0
thread 3 sees counter = 4453
expected: 4000000
counter: 1603944 (lost updates: the race)
```

With 2 threads, the recorded lost updates ranged from `671275` to `965529` (33.6% to 48.3% lost). With 4 threads, the lost updates jumped to between `2100067` and `2820770` (52.5% to 70.5% lost), because up to four threads simultaneously read stale values and overwrite one another's increments.

### Observe Answer (Part 2)

3. **In one sentence: what single idea would stop the lost updates? (You build it next week.)**  
   Protect the read-add-write sequence on `counter` with a mutual exclusion lock (mutex) so that only one thread can execute `counter++` at a time while other threads wait until the current update completes.

