#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>

/* A zombie, on purpose: parent sleeps before waiting for terminated child */
int main(int argc, char *argv[])
{
    int sleep_seconds = 20;
    if (argc > 1) {
        sleep_seconds = atoi(argv[1]);
        if (sleep_seconds <= 0) sleep_seconds = 20;
    }

    printf("parent: my PID is %d\n", getpid());
    fflush(stdout);
    pid_t pid = fork();
    if (pid < 0) { perror("fork"); return 1; }

    if (pid == 0) {
        printf("child: my PID is %d, my parent is %d\n", getpid(), getppid());
        fflush(stdout);
        execlp("ls", "ls", "-l", (char *)NULL);
        perror("exec");
        exit(127);
    }

    int status;
    sleep(sleep_seconds); /* parent sleeps while child terminates and becomes a zombie */
    waitpid(pid, &status, 0); /* step 3: reap the child */
    printf("parent: child %d ended with status %d\n", pid, WEXITSTATUS(status));
    return 0;
}
