CC = gcc
CFLAGS = -Wall -pthread
SHELL = /bin/bash

PROGS = race mutex sem order parking atomic

all: $(PROGS)

# Compile race without optimization so that counter++ remains a 3-step memory operation
race: race.c
	$(CC) $(CFLAGS) -o $@ $<

mutex: mutex.c
	$(CC) $(CFLAGS) -o $@ $<

sem: sem.c
	$(CC) $(CFLAGS) -o $@ $<

order: order.c
	$(CC) $(CFLAGS) -o $@ $<

parking: parking.c
	$(CC) $(CFLAGS) -o $@ $<

atomic: atomic.c
	$(CC) $(CFLAGS) -o $@ $<

test: all
	@echo "Testing race..."
	@./race
	@echo "Testing mutex..."
	@./mutex
	@echo "Testing sem..."
	@./sem
	@echo "Testing order..."
	@./order
	@echo "Testing parking..."
	@./parking
	@echo "Testing atomic..."
	@./atomic
	@echo "All tests passed successfully."

bench: all
	@echo "Benchmarking race:"
	@time ./race
	@echo "Benchmarking mutex:"
	@time ./mutex
	@echo "Benchmarking sem:"
	@time ./sem
	@echo "Benchmarking atomic:"
	@time ./atomic

clean:
	rm -f $(PROGS)

.PHONY: all test bench clean

