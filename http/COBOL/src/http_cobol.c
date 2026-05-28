/*
 * Copyright Core DF — Apache License 2.0
 * COBOL bridge to http/C client.
 */
#include "../../C/include/httpclient.h"
#include "../../C/include/coreauto_result.h"
#include <string.h>
#include <stdlib.h>

static void copy_str(char *dest, int dest_len, const char *src) {
    if (!dest || dest_len <= 0) return;
    if (!src) { dest[0] = '\0'; return; }
    strncpy(dest, src, (size_t)dest_len - 1);
    dest[dest_len - 1] = '\0';
}

void HTTPGET(int *status, char *body_buf, char *error_buf, char *url_buf) {
    char *json = http_get(url_buf);
    *status = 0;
    if (!json) { copy_str(error_buf, 512, "inaccessible"); return; }
    copy_str(body_buf, 8192, json);
    copy_str(error_buf, 512, "");
    coreauto_json_free(json);
    *status = 200;
}

void HTTPPOST(int *status, char *body_buf, char *error_buf, char *url_buf, char *json_body_buf) {
    char *json = http_post_json(url_buf, json_body_buf);
    *status = 0;
    if (!json) { copy_str(error_buf, 512, "inaccessible"); return; }
    copy_str(body_buf, 8192, json);
    coreauto_json_free(json);
    *status = 200;
}
