#include "kernel/types.h"
#include "user/user.h"

void
sieve(int left_fd)
{
  int p;
  if(read(left_fd, &p, sizeof(int)) != sizeof(int)){
    close(left_fd);
    exit(0);
  }

  printf("prime %d\n", p);

  int next_pipe[2];
  pipe(next_pipe);

  int pid = fork();
  if(pid < 0){
    fprintf(2, "primes: fork failed\n");
    close(left_fd);
    close(next_pipe[0]);
    close(next_pipe[1]);
    exit(1);
  }

  if(pid == 0){
    close(left_fd);
    close(next_pipe[1]);
    sieve(next_pipe[0]);
    exit(0);
  } else {
    close(next_pipe[0]);
    int n;
    while(read(left_fd, &n, sizeof(int)) == sizeof(int)){
      if(n % p != 0){
        write(next_pipe[1], &n, sizeof(int));
      }
    }
    close(left_fd);
    close(next_pipe[1]);
    wait(0);
    exit(0);
  }
}

int
main(int argc, char *argv[])
{
  int p[2];
  pipe(p);

  int pid = fork();
  if(pid < 0){
    fprintf(2, "primes: fork failed\n");
    exit(1);
  }

  if(pid == 0){
    close(p[1]);
    sieve(p[0]);
    exit(0);
  } else {
    close(p[0]);
    for(int i = 2; i <= 35; i++){
      write(p[1], &i, sizeof(int));
    }
    close(p[1]);
    wait(0);
    exit(0);
  }
}
