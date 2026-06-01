/*
 * Copyright Core DF — Apache License 2.0
 */

#include "mock_http.h"

#include <arpa/inet.h>
#include <netinet/in.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

static pid_t g_server_pid;
static int g_pipe_fd = -1;

static void handle_client(int client_fd)
{
    char buf[8192];
    ssize_t n = recv(client_fd, buf, sizeof(buf) - 1, 0);
    const char *body = "{}";
    char response[4096];
    size_t body_len;

    if (n <= 0) {
        close(client_fd);
        return;
    }
    buf[n] = '\0';

    if (strstr(buf, "/v1/auth/apicode") != NULL) {
        body = "{\"token\":\"abc\"}";
    } else if (strstr(buf, "/v1/rtevent/") != NULL) {
        body = "{\"payload\":{\"orderId\":\"1\"}}";
    } else if (strstr(buf, "/v1/keystore/") != NULL) {
        body = "{\"db_user\":\"u1\"}";
    } else if (strstr(buf, "/v1/rtstep/payload") != NULL) {
        body = "{}";
    }

    body_len = strlen(body);
    snprintf(response, sizeof(response),
             "HTTP/1.1 200 OK\r\n"
             "Content-Type: application/json\r\n"
             "Content-Length: %zu\r\n"
             "\r\n"
             "%s",
             body_len, body);
    send(client_fd, response, strlen(response), 0);
    close(client_fd);
}

static void server_main(int listen_fd, int ready_pipe)
{
    char msg[64];
    int running = 1;

    snprintf(msg, sizeof(msg), "ready\n");
    write(ready_pipe, msg, strlen(msg));
    close(ready_pipe);

    while (running) {
        struct sockaddr_in addr;
        socklen_t len = sizeof(addr);
        int client = accept(listen_fd, (struct sockaddr *)&addr, &len);
        if (client < 0) {
            break;
        }
        handle_client(client);
    }
    close(listen_fd);
    _exit(0);
}

int mock_http_start(char *base_url, size_t base_url_len)
{
    int listen_fd;
    struct sockaddr_in addr;
    socklen_t addrlen = sizeof(addr);
    int port;
    int ready_pipe[2];
    char line[32];

    if (g_server_pid > 0) {
        return 0;
    }

    listen_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (listen_fd < 0) {
        return -1;
    }

    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    addr.sin_port = 0;

    if (bind(listen_fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        close(listen_fd);
        return -1;
    }
    if (listen(listen_fd, 8) < 0) {
        close(listen_fd);
        return -1;
    }
    if (getsockname(listen_fd, (struct sockaddr *)&addr, &addrlen) < 0) {
        close(listen_fd);
        return -1;
    }
    port = ntohs(addr.sin_port);

    if (pipe(ready_pipe) < 0) {
        close(listen_fd);
        return -1;
    }

    g_server_pid = fork();
    if (g_server_pid < 0) {
        close(listen_fd);
        close(ready_pipe[0]);
        close(ready_pipe[1]);
        return -1;
    }
    if (g_server_pid == 0) {
        close(ready_pipe[0]);
        server_main(listen_fd, ready_pipe[1]);
    }

    close(listen_fd);
    close(ready_pipe[1]);
    g_pipe_fd = ready_pipe[0];
    if (read(g_pipe_fd, line, sizeof(line) - 1) <= 0) {
        mock_http_stop();
        return -1;
    }
    close(g_pipe_fd);
    g_pipe_fd = -1;

    snprintf(base_url, base_url_len, "http://127.0.0.1:%d", port);
    return 0;
}

void mock_http_stop(void)
{
    if (g_server_pid > 0) {
        kill(g_server_pid, SIGTERM);
        waitpid(g_server_pid, NULL, 0);
        g_server_pid = 0;
    }
    if (g_pipe_fd >= 0) {
        close(g_pipe_fd);
        g_pipe_fd = -1;
    }
}
