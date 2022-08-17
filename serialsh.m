#include <unistd.h>
#include <termios.h>

#import <sys/event.h>
#import <Foundation/Foundation.h>

int kq = 0;
pid_t pd = 0;

int pipe_shin[2] = { 0 };
int pipe_shout[2] = { 0 };

#define spawn_shin pipe_shin[1]
#define main_sherr pipe_shout[1]

int attribs(int fd, speed_t baudrate) {
    struct termios tty;

    memset(&tty, 0x0, sizeof(tty));

    if (tcgetattr(fd, &tty) != 0) return -1;

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
    tty.c_cc[VMIN] = 0;

    if (tcsetattr(fd, TCSANOW, &tty) != 0) return -1;

    return 0;
}

int block_attribs(int fd) {
    struct termios tty;

    memset(&tty, 0x0, sizeof(tty));

    if (tcgetattr(fd, &tty) != 0) return -1;

    tty.c_cc[VMIN] = 0;
    tty.c_cc[VTIME] = 5;

    tcsetattr(fd, TCSANOW, &tty);

    return 0;
}

void spawnproc(void) {
    struct kevent ke;

    if (pd == 0) {
        if ((pd = fork()) == 0) {
            dup2(pipe_shin[0], STDIN_FILENO);

            dup2(main_sherr, STDOUT_FILENO);
            dup2(main_sherr, STDERR_FILENO);

            char *args[] = { "-q", "/dev/null", "login" };

            execve("/usr/bin/script", args, NULL);

            exit(0);
        }

        EV_SET(&ke, pd, EVFILT_PROC, EV_ADD, NOTE_EXIT, 0, NULL);
        kevent(kq, &ke, 1, NULL, 0, NULL);
    }
}

int main(void) {
    int fd = 0;
    char buf[0x400];
    struct kevent ke;

    if (fork() == 0) {
        /* it will works the same if you open /dev/uart.debug-console */
        if ((fd = open("/dev/tty.debug-console", 133250)) > 0) {
            assert(attribs(fd, B115200) != -1);

            assert(block_attribs(fd) != -1);

            dprintf(fd, "\r\n[serialsh]: hello from the userland!\r\n\n");

            pipe(pipe_shin);
            pipe(pipe_shout);

            dup2(pipe_shout[0], STDIN_FILENO);

            dup2(spawn_shin, STDOUT_FILENO);
            dup2(spawn_shin, STDERR_FILENO);

            if ((kq = kqueue()) == -1) {
                dprintf(fd, "\r\n[serialsh]: error during initialization!\r\n\n");
                close(fd);
                return -1;
            }

            EV_SET(&ke, fd, EVFILT_READ, EV_ADD, 0, 5, 0);
            kevent(kq, &ke, 1, NULL, 0, NULL);

            EV_SET(&ke, 0, EVFILT_READ, EV_ADD, 0, 5, 0);
            kevent(kq, &ke, 1, NULL, 0, NULL);

            spawnproc();

            for (int rd = 0;;) {
                memset(&ke, 0x0, sizeof(ke));

                if (kevent(kq, NULL, 0, &ke, 1, NULL) == 0) {
                    continue;
                }

                if (ke.ident == fd) {
                    rd = read(fd, buf, 0x400);
                    write(STDOUT_FILENO, buf, rd);
                } else if (ke.ident == 0) {
                    rd = read(STDIN_FILENO, buf, 0x400);
                    write(fd, buf, rd);
                } else if ((ke.filter == EVFILT_PROC) && (ke.ident == pd)) {
                    waitpid(pd, NULL, 0);
                    pd = 0;
                    spawnproc();
                }
            }
        }
    }
}
