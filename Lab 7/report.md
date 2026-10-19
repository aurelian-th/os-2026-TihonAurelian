# Operating Systems — Laboratory Work No. 7: Three Small Programs (Linux)

**Course:** Operating Systems  
**Institution:** Technical University of Moldova (UTM), FCIM, FAF  
**Student:** Tihon Aurelian-Mihai  
**Group:** FAF-241  
**Supervisor:** univ. assist. Patricia Reițman  

---

## Part 1: Process Lifecycle (`fork` + `exec` + `wait`)

### Observations and Analysis
1. **The line `perror("exec")` is in the child, right after `execlp`. Why is it printed only with `nosuchprog`?**  
   The `exec` family of system calls (`execlp`, `execvp`, `execve`) works by replacing the current process image—including its text segment, data segment, BSS, heap, and userland stack—with the new binary executable. When `execlp` succeeds, execution branches immediately to the entry point (`_start`) of the new program (`ls` or `date`). Consequently, the instructions following `execlp` in `run.c` are completely obliterated and never execute. However, if `execlp` fails (for instance, when the binary `nosuchprog` cannot be located in the search directories defined by `$PATH`), the system call returns `-1` to the caller and sets `errno` (specifically `ENOENT`). Only in this failure case does control flow reach the subsequent statements, triggering `perror("exec")` and `exit(127)`.

2. **Which number does the child print as "my parent", and whose PID is it?**  
   The child prints the process ID returned by `getppid()`, which is identical to the PID of the parent process printed via `getpid()` in the parent branch. For example, during execution:
   ```
   parent: my PID is 26608
   child: my PID is 26609, my parent is 26608
   ```
   Here, `26608` is the PID of the original process that invoked `fork()`.

3. **What status does the parent see with `ls`, and what status with `nosuchprog`?**  
   - With `ls`, the child executes successfully and terminates by calling `exit(0)`. The parent extracts this value using `WEXITSTATUS(status)`, observing exit status **0**.
   - With `nosuchprog`, `execlp` fails, and the child explicitly calls `exit(127)`. The parent extracts this value and observes exit status **127** (the standard POSIX convention denoting command not found).

---

## Part 2: Process States & Zombies (`zombie.c`)

### Observations and Analysis
1. **Which letter does `ls` have in the `STAT` column, and what does it mean?**  
   The `ls` child process displays the letter **`Z`** (or `Z+` in foreground terminal groups) in the `STAT` column of `ps`, with command identifier `[ls] <defunct>`. This designates a **Zombie** process. A zombie is a process that has completed execution and invoked `exit()`, causing the kernel to release its virtual memory space, page tables, and file descriptors. However, the kernel retains its minimal task descriptor (`struct task_struct`) in the process table so that its termination status and resource usage statistics remain available for collection by its parent process.

2. **After 20 seconds, is the `[ls] <defunct>` line still there? Which line of `zombie.c` made it disappear?**  
   After the 20-second sleep interval expires, the `[ls] <defunct>` entry disappears completely from the process table. The line that caused it to disappear is:
   ```c
   waitpid(pid, &status, 0);
   ```
   Invoking `waitpid()` reads the child's exit status from the kernel and acknowledges its termination. Upon successful collection, the operating system reaps the dead process, freeing its PID and removing its `task_struct` entry from the global process list.

---

## Part 3: File Descriptor Redirection (`redirect.c`)

### Observations and Analysis
1. **Which number did `open` give, and why exactly that one?**  
   The `open("out.txt", ...)` system call returned file descriptor **1**. POSIX standard file descriptor allocation mandates that the kernel must always assign the lowest-numbered unused descriptor available in the per-process file descriptor table. Because the child process explicitly executed `close(1);` immediately beforehand, slot 1 (standard output) was free while slot 0 (standard input) remained occupied. Hence, `open()` deterministically claimed descriptor 1.

2. **`ls` was not changed at all. Why does its listing not appear on the screen?**  
   File descriptors are inherited across `fork()` and preserved across `exec()` unless specifically marked with the `O_CLOEXEC` / `FD_CLOEXEC` flag. Because descriptor 1 was reassigned to the file description pointing to `out.txt` prior to calling `execlp()`, any subsequent writes issued by `ls` to standard output (`fileno == 1`) are directed by the kernel Virtual File System (VFS) to the storage blocks of `out.txt` rather than the terminal device (`/dev/pts/X`).

3. **To redirect the errors instead (like `2> err.txt`), which descriptor would you close before `open`?**  
   One would execute `close(2);` prior to `open()`. Standard error is assigned file descriptor 2. Closing descriptor 2 leaves it as the lowest available descriptor (assuming 0 and 1 remain open), causing the subsequent `open("err.txt", ...)` call to allocate descriptor 2.

---

## Part 4: Inter-Process Communication Pipes (`pipeline.c`)

### Observations and Analysis
1. **Did `./pipeline` and `ls /etc | wc -l` give the same number?**  
   Yes. Both `./pipeline` and the bash pipeline command `ls /etc | wc -l` printed identical values (e.g., `261` lines).

2. **After the change, which of the two children never ends, `ls` or `wc`?**  
   The child executing **`wc`** never ends, whereas `ls` terminates normally.

3. **Why, in one sentence: what is `wc` waiting for?**  
   The `wc` utility is waiting indefinitely for an end-of-file (EOF) condition on descriptor 0, which the kernel will never signal as long as the parent process keeps a write descriptor for the pipe (`p[1]`) open in its own file descriptor table.

---

## Optional Extension: Three-Stage Pipeline (`pipeline3.c`)

The utility `pipeline3.c` implements `ls /usr/bin | grep x | wc -l` using two pipes and three concurrent child processes. Each child connects its respective standard streams via `dup()` and systematically closes all four pipe endpoints (`p1[0]`, `p1[1]`, `p2[0]`, `p2[1]`). The parent similarly closes all four endpoints and reaps all three children using `wait(NULL)`. Running `./pipeline3` outputs `249`, matching `ls /usr/bin | grep x | wc -l` identically.
