Laboratory Work No. 13: Semaphores in Your Own Kernel (xv6)
Student: Tihon Aurelian-Mihai
Group: FAF-241
Supervisor: univ. assist. Patricia Reitman

Part 3 Observe Answers

1. Without the lock, why do the letters mix? (How many system calls does one line cost?)
Each line consists of 30 characters plus 1 newline character ('\n'), costing exactly 31 individual write() system calls per line. Across 5 lines, each process executes 155 system calls.
Because xv6 executes on multiple CPU cores (CPUS=3), the parent and child processes run in parallel on separate harts. Because single-byte writes are independent system calls and no mutual exclusion lock protects the entire line, CPU scheduling preemption and simultaneous console hardware writes freely interleave the characters from both processes.

2. With the lock every line is whole. Which two lines of mix.c make one line a critical section?
The two lines that enclose the line printing loop in user/mix.c are:
  if (uselock)
    sem_down(3);
and
  if (uselock)
    sem_up(3);
The call sem_down(3) acquires semaphore 3 (initialized to 1) before the 31 characters are written, and sem_up(3) releases the semaphore only after the newline has been output, making the printing of each line an atomic critical section.

3. In sem_down the test is "while (s->value == 0)", not "if". Why can a process wake up and still find 0?
The kernel wakeup(s) function wakes up all processes waiting on channel s. When sem_up() increments s->value to 1 and issues wakeup(s), multiple sleeping processes may be awakened. Each process must acquire s->lock upon resuming. The first process to acquire the lock sees s->value == 1, decrements it to 0, and proceeds. When subsequent awakened processes acquire s->lock, s->value is already 0 again. With a while loop, these processes re-check the condition, see 0, and re-enter sleep. Using if would allow a process to proceed with s->value == 0, erroneously driving the counter negative.

4. sem_down calls release(&s->lock) BEFORE sleep(). What would go wrong if it slept holding the spinlock?
In xv6, holding a spinlock disables interrupts on the local CPU, and competing threads on other CPUs spin actively in a tight loop attempting to acquire it. If sem_down slept while holding s->lock:
First, a process attempting to signal sem_up(id) must acquire s->lock to update s->value and call wakeup(s). If s->lock is held by the sleeping process, sem_up will spin indefinitely, unable to ever wake the sleeper, creating a permanent kernel deadlock.
Second, sleeping with a spinlock violates kernel locking rules and triggers a kernel panic or deadlock. xv6 avoids this race by splitting sleep into sleep_prepare(s), releasing the spinlock, and invoking sleep().
