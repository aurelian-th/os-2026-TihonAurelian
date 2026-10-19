# Operating Systems (OS) Laboratory Works

**Author:** Tihon Aurelian-Mihai  
**Group:** FAF-241  
**Institution:** Technical University of Moldova (UTM), FCIM  
**Department:** Software Engineering and Automatics  
**Supervisor:** univ. assist. Reițman Patricia  

This repository contains the laboratory assignments, implementations, and academic reports for the Operating Systems course (2026–2027).

## Laboratory Modules

- **Lab 1: The Operating System as a Resource Manager**  
  Inspection of Linux file hierarchies, process lifetime scheduling, virtual memory translation metrics, and block devices.
- **Lab 2: xv6 Operating System Internals and System Calls**  
  Compilation, booting, and system call tracing on the RISC-V 64-bit architecture under QEMU, including custom `sleep` implementation.
- **Lab 3: The Command Line: Shell, Pipes, and Text Filters**  
  Shell execution model, pathname expansions, quote handling, file descriptor redirection, analytical stream pipelines, and automated reporting scripts.
- **Lab 4: The xv6 Shell from the Outside**  
  Comparative study between minimalist educational userland (`user/sh.c`) and GNU Bash, argument tokenization analysis (`args.c` / `args_linux.c`), and directory resolution mechanics.
- **Lab 5: The File System with Your Own Hands (Linux)**  
  VFS hierarchy inspection, inode metadata structures, hard and symbolic link mechanics, Discretionary Access Control (DAC), directory traversal search bits, sparse file allocation, and kernel pseudofilesystems (`/proc`).
- **Lab 6: Inside the xv6 File System**  
  Low-level analysis of xv6 on-disk structures, decoding file types, implementation of userland `mystat` and recursive `find` utilities, hard link lifecycle tracking across `ln` and `rm`, and verification of storage capacity limits.
- **Lab 7: Three Small Programs (Linux)**  
  Investigation of Linux process lifetime orchestration via `fork()`, `exec()`, and `waitpid()`, observation and reaping of defunct zombie processes, file descriptor table redirection without binary modifications, and construction of multi-stage inter-process communication pipelines (`pipeline` and `pipeline3`).
- **Lab 8: The Same Calls Inside Your Own OS (xv6)**  
  Porting process lifecycle management (`run.c`) to the xv6 RISC-V kernel, evaluating execution error reporting conventions against POSIX Linux, constructing a bidirectional inter-process communication exchange (`pingpong.c`) via dual unidirectional pipes, and developing a concurrent prime number sieve pipeline (`primes.c`).

