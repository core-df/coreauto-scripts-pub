/*
 * Copyright Core DF — Apache License 2.0
 * COBOL bridge to notify/C client.
 */
#include "../../C/include/notifyclient.h"
#include "../../../http/C/include/coreauto_result.h"
#include <stdlib.h>
#include <string.h>

static void copy_str(char *dest, int dest_len, const char *src) {
    if (!dest || dest_len <= 0) return;
    if (!src) { dest[0] = '\0'; return; }
    strncpy(dest, src, (size_t)dest_len - 1);
    dest[dest_len - 1] = '\0';
}

static int parse_status(const char *json) {
    if (!json) return 0;
    const char *p = strstr(json, "\"status_code\"");
    if (!p) return 0;
    p = strchr(p, ':');
    if (!p) return 0;
    return atoi(p + 1);
}

static void parse_error(const char *json, char *buf, int buflen) {
    if (!json || !buf || buflen <= 0) { buf[0] = '\0'; return; }
    const char *p = strstr(json, "\"error\"");
    if (!p) { buf[0] = '\0'; return; }
    p = strchr(p, ':');
    if (!p) { buf[0] = '\0'; return; }
    p++;
    while (*p == ' ') p++;
    if (*p != '"') { buf[0] = '\0'; return; }
    p++;
    int i = 0;
    while (*p && *p != '"' && i < buflen - 1) {
        if (*p == '\\' && p[1]) { p++; }
        buf[i++] = *p++;
    }
    buf[i] = '\0';
}

static void handle_result(char *json, int *status, char *error_buf) {
    *status = parse_status(json);
    if (*status != 200) {
        parse_error(json, error_buf, 512);
    } else {
        copy_str(error_buf, 512, "");
    }
    coreauto_json_free(json);
}

void NOTIFYSLACK(int *status, char *error_buf, char *text_buf, char *webhook_buf) {
    handle_result(notify_slack(text_buf, webhook_buf), status, error_buf);
}

void NOTIFYTEAMS(int *status, char *error_buf, char *text_buf, char *webhook_buf) {
    handle_result(notify_teams(text_buf, webhook_buf), status, error_buf);
}

void NOTIFYPAGERDUTY(int *status, char *error_buf, char *summary_buf, char *key_buf, char *severity_buf) {
    handle_result(notify_pagerduty(summary_buf, key_buf, severity_buf), status, error_buf);
}

void NOTIFYEMAIL(int *status, char *error_buf, char *subject_buf, char *body_buf, char *to_buf, char *from_buf) {
    handle_result(notify_email(subject_buf, body_buf, to_buf, from_buf), status, error_buf);
}
