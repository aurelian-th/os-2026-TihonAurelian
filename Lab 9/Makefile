CC = gcc
CFLAGS = -Wall -Wextra -O2
SHELL = /bin/bash

PROGS = syscalls

all: $(PROGS)

syscalls: syscalls.c
	$(CC) $(CFLAGS) -o $@ $<

test: all
	@echo "Testing syscalls execution..."
	@./syscalls
	@echo "Testing syscalls with strace..."
	@strace -e trace=openat,write,read,close ./syscalls 2>&1 | grep -q "hello, kernel"
	@echo "All tests passed successfully."

clean:
	rm -f $(PROGS) note.txt

.PHONY: all test clean
