CC = gcc
CFLAGS = -Wall -Wextra -O2
SHELL = /bin/bash

PROGS = run zombie redirect pipeline pipeline3

all: $(PROGS)

run: run.c
	$(CC) $(CFLAGS) -o $@ $<

zombie: zombie.c
	$(CC) $(CFLAGS) -o $@ $<

redirect: redirect.c
	$(CC) $(CFLAGS) -o $@ $<

pipeline: pipeline.c
	$(CC) $(CFLAGS) -o $@ $<

pipeline3: pipeline3.c
	$(CC) $(CFLAGS) -o $@ $<

test: all
	@echo "Testing run (default: ls -l)..."
	@./run > /dev/null
	@echo "Testing run (date)..."
	@./run date > /dev/null
	@echo "Testing redirect..."
	@./redirect > /dev/null
	@head -n 3 out.txt > /dev/null
	@echo "Testing pipeline..."
	@diff -u <(./pipeline) <(ls /etc | wc -l)
	@echo "Testing pipeline3..."
	@diff -u <(./pipeline3) <(ls /usr/bin | grep x | wc -l)
	@echo "All tests passed successfully."

clean:
	rm -f $(PROGS) out.txt

.PHONY: all test clean
