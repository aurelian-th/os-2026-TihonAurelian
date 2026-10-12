#!/usr/bin/env bash
# ==============================================================================
# OS Laboratory Work No. 5: The File System with Your Own Hands (Linux)
# Automated Verification & Empirical Exploration Script
# Author: Tihon Aurelian-Mihai (FAF-241, Variant 25)
# ==============================================================================

set -eu

WORKDIR="${HOME}/os-lab5"
mkdir -p "${WORKDIR}"
cd "${WORKDIR}"

echo "=== PART 1: The File Hierarchy Tree and File Types ==="
echo "[1.1] Listing root directory entries:"
ls -d /* | head -n 10

echo "[1.2] Distinguishing file types via directory attributes:"
ls -ld /etc /etc/passwd /bin /dev/null /tmp

echo "[1.3] Device nodes in /dev:"
ls -l /dev | head -n 10

echo "[1.4] File command analysis:"
file /usr/bin/ls /etc/passwd /bin

echo "[1.5] Disk consumption comparison:"
du -sh /var/log 2>/dev/null || true
du -sh /usr 2>/dev/null || true

echo
echo "=== PART 2: Inodes, Links, and Storage Allocation ==="
echo "[2.1] Inode assignment and initial metadata:"
rm -f notes.txt hard.txt soft.txt
echo hello > notes.txt
stat notes.txt
ls -li notes.txt

echo "[2.2] Hard link creation and original removal:"
ln notes.txt hard.txt
ls -li notes.txt hard.txt
rm notes.txt
cat hard.txt
ls -li hard.txt

echo "[2.3] Symbolic link creation and target removal:"
ln -s hard.txt soft.txt
ls -li hard.txt soft.txt
cat soft.txt
rm hard.txt
if ! cat soft.txt 2>/dev/null; then
    echo "cat soft.txt failed as expected due to broken symbolic link"
fi
ls -l soft.txt
rm -f soft.txt

echo "[2.4] Directory hard link count progression:"
rm -rf d
mkdir -p d
ls -ld d
mkdir -p d/x d/y
ls -ld d
rm -rf d

echo "[2.5] Sparse files and disk allocation metrics:"
echo x > one.txt
ls -l one.txt
du -h one.txt
truncate -s 1G big.img
ls -lh big.img
du -h big.img
rm -f one.txt big.img

echo
echo "=== PART 3: Permissions and Access Control ==="
echo "[3.1] Regular file DAC permissions:"
rm -f s.txt
echo secret > s.txt
chmod 600 s.txt
ls -l s.txt
chmod 000 s.txt
if ! cat s.txt 2>/dev/null; then
    echo "cat s.txt failed with chmod 000 as expected"
fi
chmod u+r s.txt
cat s.txt
rm -f s.txt

echo "[3.2] Current process umask and default creation modes:"
umask
rm -rf new.txt newdir
touch new.txt
mkdir newdir
ls -ld new.txt newdir
rm -rf new.txt newdir

echo "[3.3] Directory permissions: Read vs Execute:"
rm -rf box
mkdir -p box
echo "hi" > box/f
chmod u=r,go= box
echo "Listing box with read-only:"
ls box
echo "Reading box/f with read-only directory:"
if ! cat box/f 2>/dev/null; then
    echo "cat box/f failed as expected (cannot traverse without execute bit)"
fi
chmod u=x,go= box
echo "Listing box with execute-only:"
if ! ls box 2>/dev/null; then
    echo "ls box failed as expected (cannot enumerate entries without read bit)"
fi
echo "Reading box/f with execute-only directory:"
cat box/f
chmod 755 box
rm -rf box

echo "[3.4] Special permission bits (SetUID and Sticky Bit):"
ls -l /usr/bin/passwd
ls -ld /tmp
if ! cat /etc/shadow 2>/dev/null; then
    echo "cat /etc/shadow denied to non-root user as expected"
fi
ls -l /etc/shadow

echo
echo "=== PART 4: Disks and Kernel Virtual Pseudofilesystems ==="
echo "[4.1] Block devices layout:"
lsblk

echo "[4.2] Filesystem disk space usage:"
df -h /

echo "[4.3] Root mount options:"
mount | grep " / "

echo "[4.4] Virtual kernel system metrics:"
echo "Number of logical cores: $(grep -c processor /proc/cpuinfo)"
head -n 3 /proc/meminfo
head -n 5 /proc/self/status
echo "Calling process file descriptors:"
ls -l /proc/self/fd | head -n 6 || true

echo
echo "=== STRETCH TASKS ==="
echo "[S.1] Magic byte signature detection:"
gzip -c /etc/passwd > notes.gz
file notes.gz
xxd notes.gz | head -n 1
rm -f notes.gz

echo "[S.2] SetUID binary audit:"
find / -xdev -perm -4000 -type f 2>/dev/null | head -n 10

echo "Lab 5 execution completed successfully."
