# Operating Systems — Laboratory Work No. 10: Add a System Call, trace (xv6)

**Course:** Operating Systems  
**Institution:** Technical University of Moldova (UTM), FCIM, FAF  
**Student:** Tihon Aurelian-Mihai  
**Group:** FAF-241  
**Supervisor:** univ. assist. Patricia Reițman  

---

## Part 1: Userland Interface and System Call Dispatch

### Architectural Mechanics
Adding a custom system call to xv6 bridges user space and kernel space across hardware privilege boundaries:
1. **Userland Stub Generation (`user/usys.pl`):**  
   The entry `entry("trace");` directs the Perl generator script to emit the assembly stub in `user/usys.S`:
   ```assembly
   .global trace
   trace:
    li a7, SYS_trace
    ecall
    ret
   ```
   The user application places system call number `23` (`SYS_trace`) into register `a7`, places the integer argument `mask` into register `a0`, and invokes `ecall`.
2. **Trap Delegation:**  
   The CPU switches execution mode from User to Supervisor, saves registers to `p->trapframe`, and vectors control to `usertrap()` in `kernel/trap.c`, which calls `syscall()` in `kernel/syscall.c`.

### Check 1 Verification Output
Before implementing the kernel handler, invoking `trace 32 grep hello README` verifies that userland execution successfully transitions to the kernel and decodes system call number 23:
```text
$ trace 32 grep hello README
3 trace: unknown sys call 23
trace: failed
```

---

## Part 2: Kernel Implementation and Tracing Mechanism

### Modifications Summary
- **Process State Descriptor (`kernel/proc.h`):** Added `int trace_mask;` to `struct proc` to retain the active tracing filter per process.
- **Syscall Handler (`kernel/sysproc.c`):** Implemented `sys_trace()`, reading the mask argument from register `a0` using `argint(0, &mask)` and storing it in `myproc()->trace_mask`.
- **System Call Table & Names (`kernel/syscall.c`):**
  - Registered `sys_trace` at index `23` (`[SYS_trace] sys_trace`).
  - Defined lookup array `syscallnames[]` mapping integers to human-readable strings.
  - Intercepted system call completion to print the process PID, system call name, and return value (`p->trapframe->a0`) when the corresponding bit in `p->trace_mask` is active:
    ```c
    if ((p->trace_mask >> num) & 1)
      printk("%d: syscall %s -> %ld\n",
             p->pid, syscallnames[num], p->trapframe->a0);
    ```
- **Child Mask Inheritance (`kernel/proc.c`):** Inside `fork()`, propagated the mask:
  ```c
  np->trace_mask = p->trace_mask;
  ```

### Check 2 Verification Output
```text
$ trace 32 grep hello README
3: syscall read -> 1023
3: syscall read -> 965
3: syscall read -> 437
3: syscall read -> 0
```
The byte sum $1023 + 965 + 437 = 2425\text{ bytes}$ matches the exact size of `README`, read in chunks followed by EOF (`0`).

---

## Part 3: Mask Exploration & Observations

### 3.1 All Calls Traced
```text
$ trace 2147483647 grep hello README
3: syscall trace -> 0
3: syscall exec -> 3
3: syscall open -> 3
3: syscall read -> 1023
3: syscall read -> 965
3: syscall read -> 437
3: syscall read -> 0
3: syscall close -> 0
```

### 3.2 Selective Tracing of `fork` under Process Saturation
```text
$ trace 2 usertests forkforkfork
usertests starting
test forkforkfork: 3: syscall fork -> 4
4: syscall fork -> 5
5: syscall fork -> 6
...
5: syscall fork -> 64
5: syscall fork -> -1
OK
ALL TESTS PASSED
```

### 3.3 Selective Tracing of `write` (`echo hi`)
```text
$ trace 65536 echo hi
hi3: syscall write -> 2
3: syscall write -> 1
```

---

## Observations and Technical Analysis

1. **In `trace 32 grep hello README` why do you see only `read`, and not `open` or `close`?**  
   The mask integer 32 corresponds to binary $2^5 = 00100000_2$. In `kernel/syscall.h`, `SYS_read` is assigned number 5, meaning bit 5 is the sole bit asserted in the mask. System calls `SYS_open` (15) and `SYS_close` (21) correspond to bits 15 ($2^{15} = 32768$) and 21 ($2^{21} = 2097152$). In the kernel dispatch check:
   ```c
   (p->trace_mask >> num) & 1
   ```
   when `num` is 15 or 21, the expression evaluates to `0`, suppressing diagnostic emission for open and close while selectively capturing read.

2. **In `forkforkfork`, three different PIDs print lines. Which line of code from Part 2 makes that possible?**  
   The line of code in `kernel/proc.c` inside `fork()`:
   ```c
   np->trace_mask = p->trace_mask;
   ```
   When a process duplicates its address space and execution context via `fork()`, this statement explicitly copies the active `trace_mask` from the parent process structure (`p`) into the child process structure (`np`). Without this inheritance, child processes would initialize with `trace_mask = 0`, silencing all tracing output from grandchild and descendant processes.

3. **In `trace 65536 echo hi` the trace line is printed between "hi" and the new line. Why? (How many times does `echo` call `write`?)**  
   The utility `user/echo.c` invokes the `write` system call **twice**:
   - The first invocation, `write(1, "hi", 2)`, writes the characters `'h'` and `'i'` without a trailing newline. The kernel transmits these two bytes to the UART console buffer and returns to `syscall()`. Immediately following the return, the kernel tracing logic fires:
     ```c
     printk("%d: syscall write -> 2\n", p->pid);
     ```
     Because standard output did not end with a newline, the trace message is printed directly adjacent to "hi" (`hi3: syscall write -> 2\n`).
   - The second invocation, `write(1, "\n", 1)`, transmits the newline character to the console, after which the kernel tracing logic fires again:
     ```c
     printk("%d: syscall write -> 1\n", p->pid);
     ```
     producing the second trace line on a new line.

4. **Which mask traces both `open` (15) and `close` (21), and nothing else?**  
   The mask is the arithmetic sum of the corresponding bit positions:
   $$\text{Mask} = 2^{15} + 2^{21} = 32,768 + 2,097,152 = \mathbf{2,129,920}$$
   In binary notation, this corresponds to bit 15 and bit 21 set to 1:
   $$00000000001000001000000000000000_2$$
   Running `trace 2129920 grep hello README` outputs:
   ```text
   3: syscall open -> 3
   3: syscall close -> 0
   ```
