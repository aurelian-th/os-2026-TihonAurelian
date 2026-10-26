# Laboratory Work No. 2 Notes: Meet the OS You Will Build (xv6)

**Course:** Operating Systems  
**Institution:** Technical University of Moldova, FCIM, FAF  
**Student:** Tihon Aurelian-Mihai  
**Group:** FAF-241  
**Target Architecture:** RISC-V 64-bit (under QEMU)  

---

## Part 2. Use xv6 as the Unix It Is

### Questions and Observations
1. **List three programs xv6 ships with:**  
   xv6 ships with standard Unix utility programs including:
   - `ls`: lists directory contents and inode metadata.
   - `cat`: reads and concatenates file byte streams to standard output.
   - `echo`: prints argument strings to standard output.  
   *(Additional utilities include `grep`, `wc`, `mkdir`, `rm`, `kill`, and the interactive shell `sh`.)*

2. **You just used a pipe (`|`) inside xv6. Which two OS features must exist for a pipe to work?**  
   - **Process Management and Multitasking:** The operating system must support concurrent process creation, scheduling, and isolated address spaces (via `fork()` and `exec()`) so that the producer (`ls`) and consumer (`grep`) execute concurrently.
   - **Inter-Process Communication (IPC) and Synchronization:** The kernel must provide a shared in-memory byte stream buffer accessed through file descriptors, with synchronized blocking semantics (reads block when the buffer is empty, and writes block when full).

3. **In one sentence: how does the xv6 shell compare to the Linux shell from Lab 1?**  
   While both interpreters construct abstract syntax trees to orchestrate pipelines and file descriptor redirections, the xv6 shell is a minimal educational interpreter that lacks interactive command history, tab completion, environment variables, globbing, and programmable scripting constructs found in GNU Bash.

---

## Part 3. Read the Source

### Questions and Observations
1. **Which system calls does `user/cat.c` use, and what does each one ask the kernel to do?**  
   - `read(fd, buf, n)`: Requests the kernel to transfer up to `n` bytes from the file or pipe referenced by descriptor `fd` into the process memory buffer `buf`.
   - `write(fd, buf, n)`: Requests the kernel to deliver `n` bytes from memory buffer `buf` to the output stream referenced by descriptor `fd` (such as standard output 1 or standard error 2).
   - `open(path, flags)`: Requests the kernel filesystem layer to resolve the path name, allocate a file table entry, and return a lowest-available integer file descriptor configured with the specified access mode (e.g. `O_RDONLY`).
   - `close(fd)`: Requests the kernel to release the integer file descriptor and decrement the corresponding file structure's reference count.
   - `exit(status)`: Requests the kernel to terminate the calling process, reclaim its allocated virtual memory frames and page tables, and preserve the integer exit status for retrieval by `wait()`.

2. **In which kernel file, and on which line, is `sys_read` implemented?**  
   The `sys_read` function is implemented in `kernel/sysfile.c`, starting at line 69 (with `sys_write` following immediately at line 83).

3. **In one sentence: what is the difference between the code in `kernel/` and the code in `user/`?**  
   Code in `kernel/` executes in privileged RISC-V supervisor mode (S-mode) with direct hardware access to control/status registers, page tables, and physical devices, whereas code in `user/` executes in unprivileged user mode (U-mode) and must transition across the hardware trap boundary via system calls (`ecall`) to request kernel services.

---

## Part 4. First xv6 Program (`user/sleep.c`)
- Implemented `user/sleep.c` with defensive argument validation (`argc == 2`).
- Configured `Makefile` by registering `$U/_sleep\` into `UPROGS`.
- Supports both canonical `sleep()` and modern `pause()` system call prototypes via `kernel/syscall.h` definitions.
- Verified in QEMU: invoking `sleep` without arguments prints the usage diagnostic, while `sleep 10` pauses execution across timer ticks before returning to the shell prompt.
