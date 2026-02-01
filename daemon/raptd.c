/*
 * raptd - R apt daemon
 *
 * Listens on Unix socket and executes apt commands for R package installation.
 * Designed for use with r2u binary packages.
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <ctype.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <sys/wait.h>
#include <sys/stat.h>
#include <signal.h>
#include <syslog.h>
#include <fcntl.h>

#define SOCKET_PATH "/run/raptd.sock"
#define MAX_LINE 4096
#define MAX_PKGS 256
#define MAX_PKG_NAME 128

/* Validate package name: only alphanumeric, dot, underscore */
static int valid_pkg_name(const char *name) {
    if (!name || !*name)
        return 0;
    if (strlen(name) > MAX_PKG_NAME - 16)  /* room for "r-cran-" prefix */
        return 0;
    for (const char *p = name; *p; p++) {
        if (!isalnum(*p) && *p != '.' && *p != '_')
            return 0;
    }
    return 1;
}

/* Convert R package name to debian package name */
static void r_to_deb(const char *r_name, char *deb_name, size_t len) {
    snprintf(deb_name, len, "r-cran-%s", r_name);
    /* lowercase everything after prefix */
    for (char *p = deb_name + 7; *p; p++)
        *p = tolower(*p);
}

/* Execute apt-get and capture output */
static int run_apt(const char *action, char **pkgs, int npkgs, int client_fd) {
    int pipefd[2];
    if (pipe(pipefd) < 0) {
        syslog(LOG_ERR, "pipe failed: %s", strerror(errno));
        return -1;
    }

    pid_t pid = fork();
    if (pid < 0) {
        syslog(LOG_ERR, "fork failed: %s", strerror(errno));
        close(pipefd[0]);
        close(pipefd[1]);
        return -1;
    }

    if (pid == 0) {
        /* Child: execute apt-get */
        close(pipefd[0]);
        dup2(pipefd[1], STDOUT_FILENO);
        dup2(pipefd[1], STDERR_FILENO);
        close(pipefd[1]);

        /* Build argument list: apt-get <action> -y pkg1 pkg2 ... */
        char **argv = calloc(npkgs + 5, sizeof(char *));
        if (!argv)
            _exit(127);

        argv[0] = "apt-get";
        argv[1] = (char *)action;
        argv[2] = "-y";

        int argc = 3;
        char deb_name[MAX_PKG_NAME];
        for (int i = 0; i < npkgs; i++) {
            r_to_deb(pkgs[i], deb_name, sizeof(deb_name));
            argv[argc++] = strdup(deb_name);
        }
        argv[argc] = NULL;

        /* Set minimal safe environment */
        char *envp[] = {
            "PATH=/usr/sbin:/usr/bin:/sbin:/bin",
            "DEBIAN_FRONTEND=noninteractive",
            "LC_ALL=C",
            NULL
        };

        execve("/usr/bin/apt-get", argv, envp);
        _exit(127);
    }

    /* Parent: read output and send to client */
    close(pipefd[1]);

    char buf[4096];
    ssize_t n;
    while ((n = read(pipefd[0], buf, sizeof(buf))) > 0) {
        ssize_t written = 0;
        while (written < n) {
            ssize_t w = write(client_fd, buf + written, n - written);
            if (w <= 0) break;
            written += w;
        }
    }
    close(pipefd[0]);

    int status;
    waitpid(pid, &status, 0);

    int exit_code = WIFEXITED(status) ? WEXITSTATUS(status) : 127;
    return exit_code;
}

/* Handle a client connection */
static void handle_client(int client_fd) {
    char line[MAX_LINE];
    ssize_t n;

    /* Read command line */
    n = read(client_fd, line, sizeof(line) - 1);
    if (n <= 0) {
        close(client_fd);
        return;
    }
    line[n] = '\0';

    /* Strip trailing newline */
    char *nl = strchr(line, '\n');
    if (nl) *nl = '\0';

    syslog(LOG_INFO, "received: %s", line);

    /* Parse command */
    char *saveptr;
    char *cmd = strtok_r(line, " \t", &saveptr);
    if (!cmd) {
        dprintf(client_fd, "STATUS 1\nERROR: empty command\n");
        close(client_fd);
        return;
    }

    /* Validate command */
    const char *action = NULL;
    if (strcmp(cmd, "install") == 0) {
        action = "install";
    } else if (strcmp(cmd, "remove") == 0) {
        action = "remove";
    } else {
        dprintf(client_fd, "STATUS 1\nERROR: unknown command '%s'\n", cmd);
        close(client_fd);
        return;
    }

    /* Parse package names */
    char *pkgs[MAX_PKGS];
    int npkgs = 0;

    char *tok;
    while ((tok = strtok_r(NULL, " \t", &saveptr)) != NULL && npkgs < MAX_PKGS) {
        if (!valid_pkg_name(tok)) {
            dprintf(client_fd, "STATUS 1\nERROR: invalid package name '%s'\n", tok);
            close(client_fd);
            return;
        }
        pkgs[npkgs++] = tok;
    }

    if (npkgs == 0) {
        dprintf(client_fd, "STATUS 1\nERROR: no packages specified\n");
        close(client_fd);
        return;
    }

    syslog(LOG_INFO, "action=%s packages=%d", action, npkgs);

    /* Execute apt */
    int exit_code = run_apt(action, pkgs, npkgs, client_fd);
    dprintf(client_fd, "STATUS %d\n", exit_code);

    close(client_fd);
}

/* Signal handler for child reaping */
static void sigchld_handler(int sig) {
    (void)sig;
    while (waitpid(-1, NULL, WNOHANG) > 0)
        ;
}

/* Check if we were socket-activated by systemd */
static int get_systemd_socket(void) {
    const char *pid_str = getenv("LISTEN_PID");
    const char *fds_str = getenv("LISTEN_FDS");

    if (!pid_str || !fds_str)
        return -1;

    if (atoi(pid_str) != getpid())
        return -1;

    if (atoi(fds_str) < 1)
        return -1;

    /* systemd passes socket as fd 3 */
    return 3;
}

/* Create and bind socket manually */
static int create_socket(const char *path) {
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) {
        syslog(LOG_ERR, "socket: %s", strerror(errno));
        return -1;
    }

    unlink(path);

    struct sockaddr_un addr = {0};
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, path, sizeof(addr.sun_path) - 1);

    if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        syslog(LOG_ERR, "bind: %s", strerror(errno));
        close(fd);
        return -1;
    }

    /* World-writable so any user can connect */
    chmod(path, 0666);

    if (listen(fd, 16) < 0) {
        syslog(LOG_ERR, "listen: %s", strerror(errno));
        close(fd);
        return -1;
    }

    return fd;
}

int main(int argc, char **argv) {
    (void)argc;
    (void)argv;

    openlog("raptd", LOG_PID, LOG_DAEMON);
    syslog(LOG_INFO, "starting");

    /* Set up signal handler for reaping children */
    struct sigaction sa = {0};
    sa.sa_handler = sigchld_handler;
    sa.sa_flags = SA_RESTART | SA_NOCLDSTOP;
    sigaction(SIGCHLD, &sa, NULL);

    /* Get socket - either from systemd or create our own */
    int server_fd = get_systemd_socket();
    if (server_fd < 0) {
        server_fd = create_socket(SOCKET_PATH);
        if (server_fd < 0) {
            syslog(LOG_ERR, "failed to create socket");
            return 1;
        }
        syslog(LOG_INFO, "listening on %s", SOCKET_PATH);
    } else {
        syslog(LOG_INFO, "using systemd socket activation");
    }

    /* Main loop */
    for (;;) {
        int client_fd = accept(server_fd, NULL, NULL);
        if (client_fd < 0) {
            if (errno == EINTR)
                continue;
            syslog(LOG_ERR, "accept: %s", strerror(errno));
            continue;
        }

        /* Fork to handle client */
        pid_t pid = fork();
        if (pid < 0) {
            syslog(LOG_ERR, "fork: %s", strerror(errno));
            close(client_fd);
            continue;
        }

        if (pid == 0) {
            /* Child handles client */
            close(server_fd);
            handle_client(client_fd);
            _exit(0);
        }

        /* Parent continues accepting */
        close(client_fd);
    }

    return 0;
}
