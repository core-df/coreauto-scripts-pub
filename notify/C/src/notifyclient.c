/*
 * Copyright Core DF — Apache License 2.0
 */
#include "../include/notifyclient.h"
#include "../../../http/C/include/httpclient.h"
#include "../../../http/C/include/coreauto_result.h"
#include <cJSON.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include <netdb.h>
#include <sys/socket.h>

static char *post_json_webhook(const char *url, cJSON *payload)
{
    if (!url || !url[0]) {
        return coreauto_missing_env("webhook url");
    }
    char *body = cJSON_PrintUnformatted(payload);
    char *resp = http_post_json(url, body);
    free(body);
    return resp;
}

char *notify_slack(const char *text, const char *webhook_url)
{
    const char *url = webhook_url && webhook_url[0] ? webhook_url : getenv("SLACK_WEBHOOK_URL");
    if (!url || !url[0]) {
        return coreauto_missing_env("SLACK_WEBHOOK_URL");
    }
    cJSON *j = cJSON_CreateObject();
    cJSON_AddStringToObject(j, "text", text ? text : "");
    char *resp = post_json_webhook(url, j);
    cJSON_Delete(j);
    return resp;
}

char *notify_teams(const char *text, const char *webhook_url)
{
    const char *url = webhook_url && webhook_url[0] ? webhook_url : getenv("TEAMS_WEBHOOK_URL");
    if (!url || !url[0]) {
        return coreauto_missing_env("TEAMS_WEBHOOK_URL");
    }
    cJSON *j = cJSON_CreateObject();
    cJSON_AddStringToObject(j, "@type", "MessageCard");
    cJSON_AddStringToObject(j, "@context", "http://schema.org/extensions");
    cJSON_AddStringToObject(j, "text", text ? text : "");
    char *resp = post_json_webhook(url, j);
    cJSON_Delete(j);
    return resp;
}

char *notify_pagerduty(const char *summary, const char *routing_key, const char *severity)
{
    const char *key = routing_key && routing_key[0] ? routing_key : getenv("PAGERDUTY_ROUTING_KEY");
    if (!key || !key[0]) {
        return coreauto_missing_env("PAGERDUTY_ROUTING_KEY");
    }
    cJSON *payload = cJSON_CreateObject();
    cJSON_AddStringToObject(payload, "summary", summary ? summary : "");
    cJSON_AddStringToObject(payload, "severity", severity && severity[0] ? severity : "error");
    cJSON_AddStringToObject(payload, "source", "coreauto-step");
    cJSON *j = cJSON_CreateObject();
    cJSON_AddStringToObject(j, "routing_key", key);
    cJSON_AddStringToObject(j, "event_action", "trigger");
    cJSON_AddItemToObject(j, "payload", payload);
    char *resp = post_json_webhook("https://events.pagerduty.com/v2/enqueue", j);
    cJSON_Delete(j);
    return resp;
}

static int smtp_send_line(int fd, const char *line)
{
    char buf[1024];
    snprintf(buf, sizeof(buf), "%s\r\n", line);
    return (int)send(fd, buf, strlen(buf), 0) > 0;
}

static int smtp_read_response(int fd)
{
    char buf[512];
    ssize_t n = recv(fd, buf, sizeof(buf) - 1, 0);
    if (n <= 0) {
        return 0;
    }
    buf[n] = '\0';
    return buf[0] == '2' || buf[0] == '3';
}

char *notify_email(const char *subject, const char *body, const char *to_addrs, const char *from_addr)
{
    const char *host = getenv("SMTP_HOST");
    const char *port_str = getenv("SMTP_PORT");
    const char *user = getenv("SMTP_USER");
    const char *password = getenv("SMTP_PASSWORD");
    const char *sender = from_addr && from_addr[0] ? from_addr : getenv("SMTP_FROM");
    int port = port_str && port_str[0] ? atoi(port_str) : 587;

    if (!host || !host[0] || !sender || !sender[0]) {
        return coreauto_missing_env("SMTP_HOST and SMTP_FROM (or from_addr)");
    }
    if (!to_addrs || !to_addrs[0]) {
        cJSON *r = cJSON_CreateObject();
        cJSON_AddNumberToObject(r, "status_code", 500);
        cJSON_AddStringToObject(r, "error", "to_addrs required");
        char *out = cJSON_PrintUnformatted(r);
        cJSON_Delete(r);
        return out;
    }

    char portbuf[16];
    snprintf(portbuf, sizeof(portbuf), "%d", port);
    struct addrinfo hints = {0}, *res = NULL;
    hints.ai_family = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    if (getaddrinfo(host, portbuf, &hints, &res) != 0 || !res) {
        return coreauto_transport_error("smtp resolve failed");
    }

    int fd = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
    if (fd < 0 || connect(fd, res->ai_addr, res->ai_addrlen) != 0) {
        freeaddrinfo(res);
        if (fd >= 0) {
            close(fd);
        }
        return coreauto_transport_error("smtp connect failed");
    }
    freeaddrinfo(res);

    int ok = smtp_read_response(fd)
        && smtp_send_line(fd, "EHLO coreauto.local")
        && smtp_read_response(fd);

    if (user && user[0] && password && password[0]) {
        ok = ok && smtp_send_line(fd, "STARTTLS") && smtp_read_response(fd);
    }

    char mail_from[512];
    snprintf(mail_from, sizeof(mail_from), "MAIL FROM:<%s>", sender);
    ok = ok && smtp_send_line(fd, mail_from) && smtp_read_response(fd);
    char rcpt[512];
    snprintf(rcpt, sizeof(rcpt), "RCPT TO:<%s>", to_addrs);
    ok = ok && smtp_send_line(fd, rcpt) && smtp_read_response(fd);
    ok = ok && smtp_send_line(fd, "DATA") && smtp_read_response(fd);

    char msg[4096];
    snprintf(msg, sizeof(msg),
             "From: %s\r\nTo: %s\r\nSubject: %s\r\n\r\n%s\r\n.",
             sender, to_addrs, subject ? subject : "", body ? body : "");
    ok = ok && send(fd, msg, strlen(msg), 0) > 0 && smtp_read_response(fd);
    smtp_send_line(fd, "QUIT");
    close(fd);

    if (!ok) {
        return coreauto_transport_error("smtp send failed");
    }
    cJSON *r = cJSON_CreateObject();
    cJSON_AddNumberToObject(r, "status_code", 200);
    char *out = cJSON_PrintUnformatted(r);
    cJSON_Delete(r);
    return out;
}
