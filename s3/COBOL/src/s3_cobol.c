/*
 * Copyright Core DF — Apache License 2.0
 * COBOL bridge to s3/C client.
 */
#include "../../C/include/s3client.h"
#include "../../../http/C/include/coreauto_result.h"
#include <stdlib.h>
#include <string.h>

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

static void handle_simple(char *json, int *status, char *error_buf) {
    *status = parse_status(json);
    if (*status != 200) parse_error(json, error_buf, 512);
    else error_buf[0] = '\0';
    coreauto_json_free(json);
}

void S3INIT(int *status, char *error_buf) {
    handle_simple(s3_init(), status, error_buf);
}

void S3GETOBJECT(int *status, char *content_buf, char *error_buf, char *key_buf, char *bucket_buf) {
    char *json = s3_get_object(key_buf, bucket_buf);
    *status = parse_status(json);
    if (*status == 200) {
        const char *p = strstr(json, "\"content\"");
        if (p) {
            p = strchr(p, ':');
            if (p) {
                p++;
                while (*p == ' ') p++;
                if (*p == '"') {
                    p++;
                    int i = 0;
                    while (*p && *p != '"' && i < 8191) {
                        if (*p == '\\' && p[1]) p++;
                        content_buf[i++] = *p++;
                    }
                    content_buf[i] = '\0';
                }
            }
        }
        error_buf[0] = '\0';
    } else {
        parse_error(json, error_buf, 512);
        content_buf[0] = '\0';
    }
    coreauto_json_free(json);
}

void S3PUTOBJECT(int *status, char *error_buf, char *key_buf, char *content_buf, char *bucket_buf) {
    handle_simple(s3_put_object(key_buf, content_buf, bucket_buf), status, error_buf);
}

void S3LISTOBJECTS(int *status, char *keys_buf, char *error_buf, char *prefix_buf, char *bucket_buf) {
    char *json = s3_list_objects(prefix_buf, bucket_buf);
    *status = parse_status(json);
    if (*status != 200) {
        parse_error(json, error_buf, 512);
        keys_buf[0] = '\0';
    } else {
        strncpy(keys_buf, json, 8191);
        keys_buf[8191] = '\0';
        error_buf[0] = '\0';
    }
    coreauto_json_free(json);
}
