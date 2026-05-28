/*
 * Copyright Core DF — Apache License 2.0
 */
#include "../include/fileclient.h"
#include "../../../http/C/include/coreauto_result.h"

#include <cJSON.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static char *ok_content(const char *content)
{
    cJSON *r = cJSON_CreateObject();
    cJSON_AddNumberToObject(r, "status_code", 200);
    cJSON_AddStringToObject(r, "content", content ? content : "");
    char *out = cJSON_PrintUnformatted(r);
    cJSON_Delete(r);
    return out;
}

static char *os_err(const char *msg)
{
    cJSON *r = cJSON_CreateObject();
    cJSON_AddNumberToObject(r, "status_code", 500);
    cJSON_AddStringToObject(r, "error", msg ? msg : "error");
    char *out = cJSON_PrintUnformatted(r);
    cJSON_Delete(r);
    return out;
}

char *file_local_read(const char *path)
{
    FILE *f = fopen(path, "r");
    if (!f) {
        return os_err("open failed");
    }
    fseek(f, 0, SEEK_END);
    long n = ftell(f);
    fseek(f, 0, SEEK_SET);
    char *buf = malloc((size_t)n + 1);
    if (!buf) {
        fclose(f);
        return os_err("alloc failed");
    }
    fread(buf, 1, (size_t)n, f);
    buf[n] = '\0';
    fclose(f);
    char *out = ok_content(buf);
    free(buf);
    return out;
}

char *file_local_write(const char *path, const char *content)
{
    FILE *f = fopen(path, "w");
    if (!f) {
        return os_err("open failed");
    }
    if (content) {
        fputs(content, f);
    }
    fclose(f);
    cJSON *r = cJSON_CreateObject();
    cJSON_AddNumberToObject(r, "status_code", 200);
    char *out = cJSON_PrintUnformatted(r);
    cJSON_Delete(r);
    return out;
}

char *file_local_move(const char *src, const char *dest)
{
    if (rename(src, dest) != 0) {
        return os_err("rename failed");
    }
    cJSON *r = cJSON_CreateObject();
    cJSON_AddNumberToObject(r, "status_code", 200);
    char *out = cJSON_PrintUnformatted(r);
    cJSON_Delete(r);
    return out;
}
