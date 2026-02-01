/*
 * Unix domain socket support for R
 * Base R's socketConnection() doesn't support Unix sockets
 */

#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <sys/socket.h>
#include <sys/un.h>

/* Send command to Unix socket, return response */
SEXP C_rapt_call(SEXP path, SEXP command) {
    const char *sock_path = CHAR(STRING_ELT(path, 0));
    const char *cmd = CHAR(STRING_ELT(command, 0));

    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) {
        error("socket() failed: %s", strerror(errno));
    }

    struct sockaddr_un addr = {0};
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, sock_path, sizeof(addr.sun_path) - 1);

    if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        int err = errno;
        close(fd);
        if (err == ENOENT || err == ECONNREFUSED) {
            /* Daemon not running - return NULL to signal fallback */
            return R_NilValue;
        }
        error("connect() failed: %s", strerror(err));
    }

    /* Send command */
    size_t cmd_len = strlen(cmd);
    if (write(fd, cmd, cmd_len) != (ssize_t)cmd_len) {
        close(fd);
        error("write() failed: %s", strerror(errno));
    }
    if (write(fd, "\n", 1) != 1) {
        close(fd);
        error("write() failed: %s", strerror(errno));
    }

    /* Shutdown write side to signal end of request */
    shutdown(fd, SHUT_WR);

    /* Read response into buffer */
    size_t buf_size = 65536;
    size_t buf_used = 0;
    char *buf = R_alloc(buf_size, 1);

    ssize_t n;
    while ((n = read(fd, buf + buf_used, buf_size - buf_used - 1)) > 0) {
        buf_used += n;
        if (buf_used >= buf_size - 1) {
            /* Need more space - R_alloc doesn't realloc, so we copy */
            size_t new_size = buf_size * 2;
            char *new_buf = R_alloc(new_size, 1);
            memcpy(new_buf, buf, buf_used);
            buf = new_buf;
            buf_size = new_size;
        }
    }

    close(fd);

    if (n < 0) {
        error("read() failed: %s", strerror(errno));
    }

    buf[buf_used] = '\0';

    return mkString(buf);
}

/* Check if socket exists and is connectable */
SEXP C_rapt_available(SEXP path) {
    const char *sock_path = CHAR(STRING_ELT(path, 0));

    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) {
        return ScalarLogical(FALSE);
    }

    struct sockaddr_un addr = {0};
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, sock_path, sizeof(addr.sun_path) - 1);

    int result = connect(fd, (struct sockaddr *)&addr, sizeof(addr));
    close(fd);

    return ScalarLogical(result == 0);
}

/* Register routines */
static const R_CallMethodDef CallEntries[] = {
    {"C_rapt_call", (DL_FUNC) &C_rapt_call, 2},
    {"C_rapt_available", (DL_FUNC) &C_rapt_available, 1},
    {NULL, NULL, 0}
};

void R_init_rapt(DllInfo *dll) {
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
}
