CC = gcc
CFLAGS = -Wall -pthread
SHELL = /bin/bash

PROGS = prodcons condvar readers deadlock

all: $(PROGS)

prodcons: prodcons.c
	$(CC) $(CFLAGS) -o $@ $<

condvar: condvar.c
	$(CC) $(CFLAGS) -o $@ $<

readers: readers.c
	$(CC) $(CFLAGS) -o $@ $<

deadlock: deadlock.c
	$(CC) $(CFLAGS) -o $@ $<

test: all
	@echo "--- Testing prodcons ---"
	./prodcons
	@echo "--- Testing condvar ---"
	./condvar
	@echo "--- Testing readers ---"
	./readers
	@echo "--- Testing deadlock (fixed) ---"
	./deadlock

clean:
	rm -f $(PROGS)

.PHONY: all test clean

