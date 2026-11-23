# Operating Systems — Laboratory Work No. 18: Build a User-Level Thread Switch (xv6)

**Course:** Operating Systems  
**Institution:** Technical University of Moldova (UTM), FCIM, FAF  
**Student:** Tihon Aurelian-Mihai  
**Group:** FAF-241  
**Supervisor:** univ. assist. Patricia Reițman  

---

## Part 1: Cooperative User-Level Threading Architecture

### Modifications Summary (No Kernel Changes)
- **`user/uthread.c`:**
  - Defined `struct context` containing the 14 `uint64` callee-saved registers (`ra`, `sp`, `s0`–`s11`, 112 bytes total), matching the layout expected by `thread_switch`.
  - Completed `thread_schedule()` to mark `next_thread->state = RUNNING`, preserve the outgoing thread pointer `t = current_thread`, update `current_thread = next_thread`, and call `thread_switch(&t->ctx, &next_thread->ctx)`.
  - Completed `thread_create(void (*func)())` to set `t->ctx.ra = (uint64)func` and `t->ctx.sp = (uint64)(t->stack + STACK_SIZE)` so the first context switch executes `func` at the top of the 16-byte-aligned 8 KiB private stack.
  - Implemented `thread_b` and `thread_c` mirroring `thread_a` with cooperative barrier yields (`while(a_started == 0 || c_started == 0)` and `while(a_started == 0 || b_started == 0)`) and 100 counted yields each.
- **`user/uthread_switch.S`:**
  - Implemented `thread_switch` saving `ra`, `sp`, `s0`–`s11` to `0(a0)`–`104(a0)`, loading the same 14 registers from `0(a1)`–`104(a1)`, and returning via `ret`.
- **`Makefile`:**
  - Registered `$U/_uthread\` in `UPROGS` and added the link/disassembly rule for `$U/_uthread` linking `$U/uthread.o` and `$U/uthread_switch.o`.

---

## Part 2: Execution Output in xv6 QEMU

```text
$ uthread
thread_a started
thread_b started
thread_c started
thread_c 0
thread_a 0
thread_b 0
thread_c 1
thread_a 1
thread_b 1
thread_c 2
thread_a 2
thread_b 2
...
thread_c 99
thread_a 99
thread_b 99
thread_c: exit after 100
thread_a: exit after 100
thread_b: exit after 100
thread_schedule: no runnable threads
```

---

## Observe Answer

**What exactly does `thread_switch` save and load? Why is `ra` the register that makes execution continue in the other thread?**

`thread_switch(struct context *old, struct context *new)` saves the 14 RISC-V callee-saved registers (`ra`, `sp`, and `s0`–`s11`) of the outgoing thread into `old->ctx` (`0(a0)` through `104(a0)`) using `sd`, and loads those same 14 registers of the incoming thread from `new->ctx` (`0(a1)` through `104(a1)`) using `ld`. Caller-saved registers (`t0`–`t6`, `a0`–`a7`) are already spilled onto the caller's stack by the compiler when `thread_schedule` calls `thread_switch`, so only callee-saved registers plus `ra` and `sp` must be preserved across the switch.

The `ret` instruction executes `jalr x0, 0(ra)`, jumping the program counter to whatever address is held in `ra`. Because `thread_switch` overwrote `ra` with the incoming thread's saved `ra` from `new->ctx`, `ret` transfers control to the incoming thread: on its first dispatch, `ra` points to `thread_a`/`thread_b`/`thread_c` (configured by `thread_create`), and on every subsequent resume it points to the return address inside `thread_schedule` where that thread last called `thread_switch`, resuming execution seamlessly on that thread's private stack (`sp`).

