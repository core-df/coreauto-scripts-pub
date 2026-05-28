/*
 * Copyright Core DF — Apache License 2.0
 * COBOL bridge to files/C client.
 */
#include "../../C/include/fileclient.h"
#include "../../../http/C/include/coreauto_result.h"
#include <string.h>
#include <stdlib.h>

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

static void parse_content(const char *json, char *buf, int buflen) {
    if (!json || !buf || buflen <= 0) { buf[0] = '\0'; return; }
    const char *p = strstr(json, "\"content\"");
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

void FILELOCALREAD(int *status, char *content_buf, char *error_buf, char *path_buf) {
    char *json = file_local_read(path_buf);
    *status = parse_status(json);
    if (*status == 200) {
        parse_content(json, content_buf, 8192);
        copy_str(error_buf, 512, "");
    } else {
        parse_error(json, error_buf, 512);
        copy_str(content_buf, 8192, "");
    }
    coreauto_json_free(json);
}

void FILELOCALWRITE(int *status, char *error_buf, char *path_buf, char *content_buf) {
    char *json = file_local_write(path_buf, content_buf);
    *status = parse_status(json);
    if (*status != 200) parse_error(json, error_buf, 512);
    else copy_str(error_buf, 512, "");
    coreauto_json_free(json);
}

void FILELOCALMOVE(int *status, char *error_buf, char *src_buf, char *dest_buf) {
    char *json = file_local_move(src_buf, dest_buf);
    *status = parse_status(json);
    if (*status != 200) parse_error(json, error_buf, 512);
    else copy_str(error_buf, 512, "");
    coreauto_json_free(json);
}
