/*
 * Copyright Core DF — Apache License 2.0
 * Uses AWS CLI (aws) on PATH for S3 operations.
 */
#include "../include/s3client.h"
#include "../../../http/C/include/coreauto_result.h"
#include <cJSON.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static const char *env_or(const char *name, const char *fallback)
{
    const char *v = getenv(name);
    if (v && v[0]) {
        return v;
    }
    return fallback ? fallback : "";
}

static const char *bucket_name(const char *explicit_bucket)
{
    if (explicit_bucket && explicit_bucket[0]) {
        return explicit_bucket;
    }
    return env_or("S3_BUCKET", "");
}

static char *aws_base(void)
{
    const char *region = env_or("AWS_REGION", env_or("AWS_DEFAULT_REGION", "us-east-1"));
    const char *endpoint = env_or("S3_ENDPOINT_URL", "");
    char *buf = malloc(512);
    if (!buf) {
        return NULL;
    }
    if (endpoint[0]) {
        snprintf(buf, 512, "aws --region %s --endpoint-url %s", region, endpoint);
    } else {
        snprintf(buf, 512, "aws --region %s", region);
    }
    return buf;
}

static char *run_cmd(const char *cmd)
{
    FILE *fp = popen(cmd, "r");
    if (!fp) {
        return coreauto_transport_error("command failed");
    }
    size_t cap = 4096;
    size_t len = 0;
    char *out = malloc(cap);
    if (!out) {
        pclose(fp);
        return coreauto_transport_error("alloc failed");
    }
    char chunk[1024];
    while (fgets(chunk, sizeof(chunk), fp)) {
        size_t clen = strlen(chunk);
        if (len + clen + 1 > cap) {
            cap *= 2;
            char *n = realloc(out, cap);
            if (!n) {
                free(out);
                pclose(fp);
                return coreauto_transport_error("alloc failed");
            }
            out = n;
        }
        memcpy(out + len, chunk, clen);
        len += clen;
    }
    int rc = pclose(fp);
    out[len] = '\0';
    if (rc != 0) {
        cJSON *r = cJSON_CreateObject();
        cJSON_AddNumberToObject(r, "status_code", 0);
        cJSON_AddStringToObject(r, "error", out);
        char *json = cJSON_PrintUnformatted(r);
        cJSON_Delete(r);
        free(out);
        return json;
    }
    return out;
}

char *s3_init(void)
{
    if (!env_or("AWS_ACCESS_KEY_ID", "")[0] && !env_or("AWS_PROFILE", "")[0]) {
        return coreauto_missing_env("AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY or AWS_PROFILE");
    }
    if (!env_or("S3_BUCKET", "")[0]) {
        return coreauto_missing_env("S3_BUCKET (or pass bucket per call)");
    }
    cJSON *r = cJSON_CreateObject();
    cJSON_AddNumberToObject(r, "status_code", 200);
    char *out = cJSON_PrintUnformatted(r);
    cJSON_Delete(r);
    return out;
}

char *s3_get_object(const char *key, const char *bucket)
{
    const char *b = bucket_name(bucket);
    if (!b[0]) {
        return coreauto_missing_env("S3_BUCKET");
    }
    char *base = aws_base();
    if (!base) {
        return coreauto_transport_error("aws base failed");
    }
    char *cmd = malloc(strlen(base) + strlen(b) + strlen(key) + 64);
    snprintf(cmd, strlen(base) + strlen(b) + strlen(key) + 64, "%s s3 cp s3://%s/%s -", base, b, key);
    char *raw = run_cmd(cmd);
    free(cmd);
    free(base);
    if (raw && raw[0] == '{') {
        return raw;
    }
    cJSON *r = cJSON_CreateObject();
    cJSON_AddNumberToObject(r, "status_code", 200);
    cJSON_AddStringToObject(r, "content", raw ? raw : "");
    char *out = cJSON_PrintUnformatted(r);
    cJSON_Delete(r);
    free(raw);
    return out;
}

char *s3_put_object(const char *key, const char *content, const char *bucket)
{
    const char *b = bucket_name(bucket);
    if (!b[0]) {
        return coreauto_missing_env("S3_BUCKET");
    }
    char tmpl[] = "/tmp/coreauto_s3_XXXXXX";
    int fd = mkstemp(tmpl);
    if (fd < 0) {
        return coreauto_transport_error("temp file failed");
    }
    if (content) {
        write(fd, content, strlen(content));
    }
    close(fd);

    char *base = aws_base();
    char *cmd = malloc(strlen(base) + strlen(b) + strlen(key) + strlen(tmpl) + 64);
    snprintf(cmd, strlen(base) + strlen(b) + strlen(key) + strlen(tmpl) + 64,
             "%s s3 cp %s s3://%s/%s", base, tmpl, b, key);
    char *raw = run_cmd(cmd);
    unlink(tmpl);
    free(cmd);
    free(base);
    if (raw && raw[0] == '{') {
        return raw;
    }
    free(raw);
    cJSON *r = cJSON_CreateObject();
    cJSON_AddNumberToObject(r, "status_code", 200);
    char *out = cJSON_PrintUnformatted(r);
    cJSON_Delete(r);
    return out;
}

char *s3_list_objects(const char *prefix, const char *bucket)
{
    const char *b = bucket_name(bucket);
    if (!b[0]) {
        return coreauto_missing_env("S3_BUCKET");
    }
    const char *pfx = prefix ? prefix : "";
    char *base = aws_base();
    char uri[512];
    snprintf(uri, sizeof(uri), "s3://%s/%s", b, pfx);
    char *cmd = malloc(strlen(base) + strlen(uri) + 64);
    snprintf(cmd, strlen(base) + strlen(uri) + 64, "%s s3 ls %s --recursive", base, uri);
    char *raw = run_cmd(cmd);
    free(cmd);
    free(base);
    if (raw && raw[0] == '{') {
        return raw;
    }

    cJSON *keys = cJSON_CreateArray();
    char *line = raw ? strtok(raw, "\n") : NULL;
    while (line) {
        char *last = strrchr(line, ' ');
        if (last && last[1]) {
            cJSON_AddItemToArray(keys, cJSON_CreateString(last + 1));
        }
        line = strtok(NULL, "\n");
    }
    free(raw);

    cJSON *r = cJSON_CreateObject();
    cJSON_AddNumberToObject(r, "status_code", 200);
    cJSON_AddItemToObject(r, "keys", keys);
    char *out = cJSON_PrintUnformatted(r);
    cJSON_Delete(r);
    return out;
}
