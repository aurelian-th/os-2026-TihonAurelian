#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>

/* 3-stage pipeline:
   ls /usr/bin | grep x | wc -l
*/
int main(void)
{
    int p1[2];
    int p2[2];

    if (pipe(p1) < 0) { perror("pipe p1"); return 1; }
    if (pipe(p2) < 0) { perror("pipe p2"); return 1; }

    /* Stage 1: ls /usr/bin */
    if (fork() == 0) {
        close(1);
        if (dup(p1[1]) < 0) { perror("dup p1[1]"); exit(1); }
        close(p1[0]); close(p1[1]);
        close(p2[0]); close(p2[1]);
        execlp("ls", "ls", "/usr/bin", (char *)NULL);
        perror("exec ls");
        exit(127);
    }

    /* Stage 2: grep x */
    if (fork() == 0) {
        close(0);
        if (dup(p1[0]) < 0) { perror("dup p1[0]"); exit(1); }
        close(1);
        if (dup(p2[1]) < 0) { perror("dup p2[1]"); exit(1); }
        close(p1[0]); close(p1[1]);
        close(p2[0]); close(p2[1]);
        execlp("grep", "grep", "x", (char *)NULL);
        perror("exec grep");
        exit(127);
    }

    /* Stage 3: wc -l */
    if (fork() == 0) {
        close(0);
        if (dup(p2[0]) < 0) { perror("dup p2[0]"); exit(1); }
        close(p1[0]); close(p1[1]);
        close(p2[0]); close(p2[1]);
        execlp("wc", "wc", "-l", (char *)NULL);
        perror("exec wc");
        exit(127);
    }

    /* Parent closes all four descriptor endpoints */
    close(p1[0]); close(p1[1]);
    close(p2[0]); close(p2[1]);

    wait(NULL);
    wait(NULL);
    wait(NULL);
    return 0;
}
