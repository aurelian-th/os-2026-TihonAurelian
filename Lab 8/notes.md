# Operating Systems — Laboratory Work No. 8: The Same Calls Inside Your Own OS (xv6)

**Course:** Operating Systems  
**Institution:** Technical University of Moldova (UTM), FCIM, FAF  
**Student:** Tihon Aurelian-Mihai  
**Group:** FAF-241  
**Supervisor:** univ. assist. Patricia Reițman  

---

## Part 1: Process Lifecycle inside xv6 (`user/run.c`)

### Observations and Analysis
1. **Write the three calls that `run.c` uses in xv6 and the three calls `run.c` used on Linux in Lab 7. What is the same?**  
   - **Inside xv6 (`user/run.c`):**
     1. `fork()` — duplicates the calling process address space.
     2. `exec(char *path, char **argv)` — replaces the memory image of the process with the new executable.
     3. `wait(int *status)` — blocks the caller until a child terminates and collects its integer exit code.
   - **On Linux (`run.c`):**
     1. `fork()` — duplicates the process image via copy-on-write page table mapping.
     2. `execlp(const char *file, const char *arg, ...)` — C library wrapper invoking the kernel's `execve()` system call with `$PATH` resolution.
     3. `waitpid(pid_t pid, int *status, int options)` — waits for a specific child PID with options.
   - **What is the same:** The fundamental three-step Unix process orchestration model is conceptually and syntactically identical across both operating systems:
     - Process creation is separated from program execution.
     - The parent clones itself (`fork`).
     - The child transitions to a new program (`exec`).
     - The parent synchronizes execution and reaps the child's termination status (`wait`).

2. **Who prints "hello from the child": the code of `run`, or `echo`?**  
   It is printed exclusively by the `echo` utility (`user/echo.c`). The `run` process merely marshals the command string and pointer arguments in its stack (`char *args[] = { "echo", "hello", "from", "the", "child", 0 };`) and issues the `exec()` system call. Once the kernel validates the ELF binary and switches the program counter, the code and stack of `run` cease to exist. The instructions executing `printf()` are those of `echo` iterating over `argv[1..n]`.

3. **Why is the status 1 here and 127 on Linux? (Look at the exit line after exec in both programs.)**  
   In both operating systems, when `exec()` fails, control returns to the instruction immediately following the call.
   - In xv6 (`user/run.c`), the failure fallback path is:
     ```c
     printf("exec failed\n");
     exit(1);
     ```
     The child explicitly passes `1` to `exit()`, so the kernel records `1` in the proc struct `p->xstate`, which `wait(&status)` writes directly into `status`.
   - In Linux (`run.c`), the failure fallback path is:
     ```c
     perror("exec");
     exit(127);
     ```
     The child explicitly passes `127` to `exit()`, adhering to the standard POSIX shell convention where exit status `127` specifically denotes "command not found".

---

## Part 2: Inter-Process Communication via Pipes (`user/pingpong.c`)

### Observations and Analysis
1. **Why do you need TWO pipes, and not one for both directions?**  
   A Unix pipe represents a unidirectional byte stream operating as a FIFO (First-In, First-Out) circular buffer managed by the kernel. Data written to the write end (`p[1]`) is queued until consumed from the read end (`p[0]`). If a single bidirectional pipe were used:
   - When the parent writes the byte `'x'` and immediately invokes `read()`, a race condition occurs: the parent may read back its own byte before the child process is scheduled by the kernel.
   - If the child attempts to read while the parent has already consumed the byte, the child blocks indefinitely, resulting in a deadlock.
   Using two dedicated pipes (`p2c` for Parent-to-Child and `c2p` for Child-to-Parent) completely isolates the two communication channels, guaranteeing deterministic, deadlock-free communication.

2. **Nothing in your code says "wait until the child has replied". Which call makes the parent wait?**  
   The call `read(c2p[0], &b, 1)` makes the parent wait. By default, `read()` on an empty pipe is a blocking system call. Because the child has not yet written the response byte into `c2p[1]`, the kernel suspends the parent process, transitions its state to `SLEEPING` (`p->state = SLEEPING`), and yields the CPU core to other runnable processes. The parent only transitions back to `RUNNABLE` when the child's `write(c2p[1], &b, 1)` places data into the pipe buffer and invokes `wakeup()`.

---

## Optional Extension: Concurrent Prime Sieve (`user/primes.c`)

The utility `user/primes.c` implements the concurrent Sieve of Eratosthenes pipeline proposed by Doug McIlroy. The initial process generates integers $2 \le n \le 35$ into a pipe. Each successive child process acts as an autonomous sieve stage:
1. It reads the first integer from its upstream pipe, which is guaranteed to be prime ($p$), and prints `"prime %d\n", p`.
2. It constructs a new downstream pipe and forks a child worker for the subsequent stage.
3. It iterates over incoming numbers from the upstream pipe, discarding all multiples of $p$ ($n \pmod p == 0$) and forwarding coprime numbers ($n \pmod p \ne 0$) into the downstream pipe.
4. When the upstream stream reaches EOF, the stage closes all pipe descriptors, waits for its child to terminate via `wait(0)`, and exits cleanly.

Because xv6 limits each process to 16 file descriptors (`NOFILE = 16`), every stage strictly closes unused pipe endpoints immediately after creation, guaranteeing safe execution within kernel resource boundaries.
