#include "kernel/types.h"
#include "kernel/syscall.h"
#include "user/user.h"

int
main(int argc, char *argv[])
{
  if(argc != 2){
    fprintf(2, "usage: sleep <ticks>\n");
    exit(1);
  }

#if defined(SYS_pause)
  pause(atoi(argv[1]));
#else
  sleep(atoi(argv[1]));
#endif

  exit(0);
}
