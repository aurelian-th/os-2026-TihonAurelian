#!/bin/bash
# Operating Systems - Laboratory Work No. 3
# One-liner stream filtering pipelines for access.log and system analysis
# Author: Tihon Aurelian-Mihai (FAF-241)

# Ensure access.log is accessible
if [ ! -f "access.log" ] && [ -f "$HOME/os-lab3/access.log" ]; then
    cp "$HOME/os-lab3/access.log" .
fi

echo "--- Q1. How many requests failed? ---"
grep -c "FAIL" access.log

echo "--- Q2. How many different pages were requested, and which? ---"
cut -d' ' -f5 access.log | sort -u

echo "--- Q3. How many requests did each page get? ---"
cut -d' ' -f5 access.log | sort | uniq -c

echo "--- Q4. Which user or users have the most failed requests, and how many? ---"
grep "FAIL" access.log | cut -d' ' -f3 | sort | uniq -c | sort -rn | head -n 2

echo "--- Q5. How many requests did user3 make, and how many of them failed? ---"
echo "Total requests: $(grep -c "user3 " access.log), Failed requests: $(grep "user3 " access.log | grep -c "FAIL")"

echo "--- Q6. Print the last 3 failed requests, showing only time and user ---"
grep "FAIL" access.log | tail -n 3 | cut -d' ' -f2,3

echo "--- Q7. Which login shells appear in /etc/passwd, and how many accounts use each? ---"
cut -d: -f7 /etc/passwd | sort | uniq -c | sort -rn

echo "--- Q8. Compare line counts of ls /etc and ls -l /etc ---"
echo "ls /etc count: $(ls /etc | wc -l) | ls -l /etc count: $(ls -l /etc | wc -l)"

echo "--- Bonus: Lines where the minute ends in 0 and request failed ---"
grep -E "10:[0-5]0 .* FAIL" access.log
echo "Total bonus matches: $(grep -E "10:[0-5]0 .* FAIL" access.log | wc -l)"
