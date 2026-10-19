#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>

/* the three steps of the shell for the command:
   ls -l
*/
int main(int argc, char *argv[])
{
    printf("parent: my PID is %d\n", getpid());
    fflush(stdout);
    pid_t pid = fork();
    if (pid < 0) { perror("fork"); return 1; }

    /* step 1: copy myself */

    if (pid == 0) {
        /* only the child runs this */
        printf("child: my PID is %d, my parent is %d\n", getpid(), getppid());
        fflush(stdout);
        if (argc > 1) {
            execvp(argv[1], &argv[1]);
        } else {
            execlp("ls", "ls", "-l", (char *)NULL); /* step 2: become ls */
        }
        perror("exec");
        /* runs only if exec failed */
        exit(127);
    }
    int status;
    waitpid(pid, &status, 0);
    /* step 3: wait for the child */
    printf("parent: child %d ended with status %d\n", pid, WEXITSTATUS(status));
    return 0;
}
