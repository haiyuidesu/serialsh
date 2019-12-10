#include <unistd.h>
#include <termios.h>
#import <sys/event.h>
#import <Foundation/Foundation.h>

pid_t pd = 0;
int pipe_shin[2], pipe_shout[2];

int 
attribs(int fd, int baudrate) {
  struct termios tty;

  memset(&tty, 0x0, sizeof(tty));

  if (tcgetattr(fd, &tty) != 0) 
    return -1;

  cfsetispeed(&tty, baudrate);
  cfsetospeed(&tty, baudrate);

  tty.c_cflag &= ~CRTSCTS;
  tty.c_cflag |= (CLOCAL | CREAD);
  tty.c_iflag |= IGNPAR;
  tty.c_iflag &= ~(IXON | IXOFF | INLCR | IGNCR);
  tty.c_oflag &= ~OPOST;
  tty.c_cflag &= ~CSIZE;
  tty.c_cflag |= CS8;
  tty.c_cflag &= ~PARENB;
  tty.c_iflag &= ~INPCK;
  tty.c_cflag &= ~CSTOPB;
  tty.c_iflag |= INPCK;
  tty.c_cc[VTIME] = 1;
  tty.c_cc[VMIN]  = 0;

  if (tcsetattr(fd, TCSANOW, &tty) != 0)
    return -1; 

  return 0;
}

#define spawn_shin pipe_shin[1]
#define main_sherr pipe_shout[1]

void 
block_attribs(int fd, int block_now) {
  struct termios tty;
  memset(&tty, 0x0, sizeof(tty));

  if (tcgetattr(fd, &tty) != 0) 
    return;

  tty.c_cc[VMIN]  = block_now ? 1 : 0;
  tty.c_cc[VTIME] = 5;
  tcsetattr(fd, TCSANOW, &tty);
}

int kq = 0;
void spawnproc(void) {
  if (pd == 0) {
    pd = fork();

    if (pd == 0) {
      dup2(pipe_shin[0], 0);
      dup2(main_sherr, 1);
      dup2(main_sherr, 2);
      char *paramList[] = { "createpty", "-q", "/dev/null", "login" };
      execv("/usr/bin/script", paramList);
      exit(0);
    }

    struct kevent ke;
    EV_SET(&ke, pd, EVFILT_PROC, EV_ADD, NOTE_EXIT, 0, NULL);
    kevent(kq, &ke, 1, NULL, 0, NULL);
  }
}

int main(void) {
  if (fork() == 0) {
    // int fd = open("/dev/tty.uart-console", 133250);
    int fd = open("/dev/tty.debug-console", O_RDWR | O_NOCTTY | O_SYNC | O_NONBLOCK);
    if (!(fd < 0)) {
      attribs(fd, B115200);
      block_attribs(fd, 0);

      write(fd, "\r\n[serialsh]: initialized from the userland!\r\n", 46); // 0x2EuLL

      pipe(pipe_shin);
      pipe(pipe_shout);

      dup2(pipe_shout[0], 0);
      dup2(spawn_shin, 1);
      dup2(spawn_shin, 2);

      kq = kqueue();
      assert(kq != -1);
      struct kevent ke;
      char buf[0x400]; // 1024 bytes buffer
      EV_SET(&ke, fd, EVFILT_READ, EV_ADD, 0, 5, NULL);
      kevent(kq, &ke, 1, NULL, 0, NULL);
      EV_SET(&ke, 0, EVFILT_READ, EV_ADD, 0, 5, NULL);
      kevent(kq, &ke, 1, NULL, 0, NULL);
      spawnproc();

      while (1) {
        EV_SET(&ke, 0, 0, 0, 0, 0, NULL);
        int uwu = kevent(kq, NULL, 0, &ke, 1, NULL);
        if (uwu == 0) 
          continue;
        if (ke.ident == fd) {
          int rd = read(fd, buf, 0x400);
          write(1, buf, rd);
        } else if (ke.ident == 0) {
          int rd = read(0, buf, 0x400);
          write(fd, buf, rd);
        } else if ((ke.filter == -5) && (ke.ident == pd)) {
          waitpid(pd, NULL, 0x0);
          pd = 0;
          spawnproc();
        }
      }
    }
  }
}