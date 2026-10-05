#!/bin/bash
# usage: ./report.sh access.log
# Operating Systems - Laboratory Work No. 3
# Author: Tihon Aurelian-Mihai (FAF-241)

log=$1
if [ ! -f "$log" ]; then
    echo "no such file: $log" >&2
    exit 1
fi

total=$(wc -l < "$log")
fails=$(grep -c FAIL "$log")
echo "$total requests, $fails failed"

# Print failures for each user from user0 to user6
for u in {0..6}; do
    u_fails=$(grep "user$u " "$log" | grep -c "FAIL")
    echo "user$u: $u_fails failures"
done
