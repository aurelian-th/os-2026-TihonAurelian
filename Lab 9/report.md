# Operating Systems — Laboratory Work No. 9: Watching System Calls (Linux)

**Course:** Operating Systems  
**Institution:** Technical University of Moldova (UTM), FCIM, FAF  
**Student:** Tihon Aurelian-Mihai  
**Group:** FAF-241  
**Supervisor:** univ. assist. Patricia Reițman  

---

## Part 1: Inspecting System Calls of a Real Command (`ls -l`)

### Execution Command
```bash
strace -f -e trace=openat,read,write,close ls -l
```

### Observations and Analysis
1. **Which system call does `ls` use to print to the screen? To which descriptor does it write?**  
   The `ls` utility uses the **`write`** system call to print to the screen, specifically writing to **file descriptor `1`** (Standard Output, `STDOUT_FILENO`).  
   In Linux, when a terminal emulator or shell launches a program, file descriptor 1 is connected to the pseudo-terminal device slave (such as `/dev/pts/2`). The system call invocation captured by `strace` appears as:
   ```text
   write(1, "total 300\n-rw-rw-r-- 1 phantom p"..., 113) = 113
   ```
   The `ls` program buffers its formatted directory output in userland memory (`libc` `stdio` buffer) and performs a single vectorized or bulk `write()` call to descriptor 1, flushing the entire listing to the terminal at once.

2. **System Call Frequency and Lifecycle in a Standard Command:**  
   Although `ls` appears to be a trivial utility, executing `ls -l` issues dozens of kernel transitions before a single byte of user output appears:
   - Dynamic linker (`ld.so`) loads shared libraries (`libc.so.6`, `libselinux.so.1`, `libpcre2-8.so.0`) by calling `openat()` on `/etc/ld.so.cache` and library paths, issuing `read()` for ELF headers, and closing them with `close()`.
   - Locale and timezone files are opened and parsed (`/usr/share/zoneinfo/Europe/Bucharest`).
   - The current working directory `.` is opened with `openat(AT_FDCWD, ".", O_RDONLY|O_NONBLOCK|O_CLOEXEC|O_DIRECTORY)`.
   - Name service configuration and user/group database files (`/etc/nsswitch.conf`, `/etc/passwd`, `/etc/group`) are read to map numeric UIDs and GIDs to human-readable account names (`phantom`).
   - Finally, `write(1, ...)` outputs the formatted directory table.

---

## Part 2: Direct Kernel Invocations (`syscalls.c`)

### Source Implementation
The program `syscalls.c` bypasses high-level standard I/O abstractions (`fopen`, `fprintf`, `fread`) for file storage operations, communicating directly with the Linux kernel through primitive POSIX system calls (`open`, `write`, `read`, `close`):

```c
#include <fcntl.h>   /* open */
#include <unistd.h>  /* write, read, close */
#include <string.h>  /* strlen */
#include <stdio.h>   /* printf */

int main(void) {
    const char *msg = "hello, kernel\n";

    /* open() is a system call: ask the kernel for a file, get back a descriptor */
    int fd = open("note.txt", O_CREAT | O_WRONLY | O_TRUNC, 0644);
    if (fd < 0) { perror("open"); return 1; }
    printf("open returned descriptor %d\n", fd);

    /* write() is a system call: hand the bytes to the kernel */
    ssize_t n = write(fd, msg, strlen(msg));
    printf("write sent %zd bytes\n", n);
    close(fd);

    /* read it back, through the kernel again */
    fd = open("note.txt", O_RDONLY);
    char buf[64];
    n = read(fd, buf, sizeof(buf) - 1);
    buf[n] = '\0';
    printf("read got %zd bytes: %s", n, buf);
    close(fd);

    return 0;
}
```

### Execution Outputs
Direct execution produces:
```text
open returned descriptor 3
write sent 14 bytes
read got 14 bytes: hello, kernel
```

Under `strace -e trace=openat,write,read,close ./syscalls`:
```text
openat(AT_FDCWD, "note.txt", O_WRONLY|O_CREAT|O_TRUNC, 0644) = 3
write(1, "open returned descriptor 3\n", 27) = 27
write(3, "hello, kernel\n", 14)         = 14
write(1, "write sent 14 bytes\n", 20)   = 20
close(3)                                = 0
openat(AT_FDCWD, "note.txt", O_RDONLY)  = 3
read(3, "hello, kernel\n", 63)          = 14
write(1, "read got 14 bytes: hello, kernel\n", 33) = 33
close(3)                                = 0
```

### Observations and Analysis
1. **The descriptor returned by the first `openat` is 3, not 0, 1, or 2. Why are those three already taken?**  
   Under Unix and POSIX system architectures, when any process is created (via `fork()` and initialized by the C runtime before `main()` executes), the operating system automatically assigns three standard streams to the lowest numerical entries of the process's file descriptor table:
   - **Descriptor `0` (`stdin`):** Standard input stream, bound to the terminal keyboard input.
   - **Descriptor `1` (`stdout`):** Standard output stream, bound to the terminal display for regular textual output.
   - **Descriptor `2` (`stderr`):** Standard error stream, bound to the terminal display for diagnostic and error logging.
   
   The POSIX specification dictates that whenever the kernel allocates a new file descriptor (via `open`, `openat`, `pipe`, `creat`, or `dup`), it must systematically scan the calling process's descriptor table (`task_struct->files->fdt`) from left to right and allocate the **lowest-numbered unallocated index**. Since slots 0, 1, and 2 are populated during process initialization, the lowest vacant descriptor index available is **3**.

2. **Re-allocation of Descriptor 3:**  
   After closing descriptor 3 via `close(fd);`, descriptor slot 3 returns to the pool of unallocated descriptors. Consequently, the subsequent `open("note.txt", O_RDONLY)` again finds slot 3 as the lowest available slot and allocates descriptor **3** a second time.

---

## Part 3: Counting One Kind of Call (`strace -c`)

### Execution Command
```bash
strace -c -e trace=write ./syscalls
```
Complementary execution on a standard command:
```bash
strace -c -e trace=write ls -l
```

### Execution Outputs
Executing `strace -c -e trace=write ./syscalls`:
```text
open returned descriptor 3
write sent 14 bytes
read got 14 bytes: hello, kernel
% time     seconds  usecs/call     calls    errors syscall
------ ----------- ----------- --------- --------- ----------------
100.00    0.000047          11         4           write
------ ----------- ----------- --------- --------- ----------------
100.00    0.000047          11         4           total
```

Executing `strace -c -e trace=write ls -l`:
```text
% time     seconds  usecs/call     calls    errors syscall
------ ----------- ----------- --------- --------- ----------------
100.00    0.000021          21         1           write
------ ----------- ----------- --------- --------- ----------------
100.00    0.000021          21         1           total
```

### Observations and Analysis
1. **Profiling Mechanics of `strace -c`:**  
   The `-c` (summary-only) option instructs `strace` to intercept system call entries and exits silently during execution, recording timing metrics, call frequencies, and error occurrences in an internal hash table. Upon process termination, `strace` emits a clean tabular breakdown detailing percentage of execution time, total elapsed seconds, microsecond latency per call, total calls, and error counts.

2. **Targeted Counting of a Single System Call Class:**  
   By combining `-c` with `-e trace=write`, `strace` isolates and tallies solely the specified system call:
   - For `./syscalls`, the summary registers exactly 4 `write` invocations: three status strings formatted and emitted via `printf()` to standard output (`STDOUT_FILENO`), and one direct unbuffered payload transfer (`write(3, msg, 14)`) to `note.txt`.
   - For `ls -l`, the summary registers exactly 1 `write` invocation, confirming that `ls` collects directory entries in userland memory and flushes the entire formatted listing in a single batch transmission to descriptor 1.
