CC = gcc
CFLAGS = -Wall -Wextra -pthread
SHELL = /bin/bash

PROGS = fire

all: $(PROGS)

# Compile without -O2 so counter++ remains a three-step memory operation
fire: fire.c
	$(CC) $(CFLAGS) -o $@ $<

test: all
	@./fire

clean:
	rm -f $(PROGS)

.PHONY: all test clean

