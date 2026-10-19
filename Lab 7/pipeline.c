#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>

/* does the same as the shell command:
   ls /etc | wc -l
*/
int main(int argc, char *argv[])
{
    int intentional_bug = (argc > 1 && argv[1][0] == 'b');
    int p[2];
    if (pipe(p) < 0) { perror("pipe"); return 1; }

    if (fork() == 0) {
        /* ls: its 1 becomes p[1] */
        close(1);
        if (dup(p[1]) < 0) { perror("dup p[1]"); exit(1); }
        close(p[0]);
        close(p[1]);
        execlp("ls", "ls", "/etc", (char *)NULL);
        perror("exec ls");
        exit(127);
    }

    if (fork() == 0) {
        /* wc: its 0 becomes p[0] */
        close(0);
        if (dup(p[0]) < 0) { perror("dup p[0]"); exit(1); }
        close(p[0]);
        close(p[1]);
        execlp("wc", "wc", "-l", (char *)NULL);
        perror("exec wc");
        exit(127);
    }

    /* the parent uses neither end */
    close(p[0]);
    if (!intentional_bug) {
        close(p[1]);
    } else {
        fprintf(stderr, "parent: intentional bug active (p[1] kept open)\n");
    }

    wait(NULL);
    wait(NULL);
    return 0;
}
