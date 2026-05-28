/*
 * Copyright Core DF — Apache License 2.0
 */

#include "../include/httpclient.h"
#include "../include/coreauto_result.h"

#include <curl/curl.h>
#include <cJSON.h>
#include <stdlib.h>
#include <string.h>

struct curl_buf {
    char *data;
    size_t len;
};

static size_t curl_write(void *ptr, size_t size, size_t nmemb, void *userdata)
{
    size_t n = size * nmemb;
    struct curl_buf *buf = (struct curl_buf *)userdata;
    char *p = realloc(buf->data, buf->len + n + 1);
    if (!p) {
        return 0;
    }
    buf->data = p;
    memcpy(buf->data + buf->len, ptr, n);
    buf->len += n;
    buf->data[buf->len] = '\0';
    return n;
}

static cJSON *parse_body(const char *raw)
{
    if (!raw || !raw[0]) {
        return cJSON_CreateNull();
    }
    cJSON *j = cJSON_Parse(raw);
    if (j) {
        return j;
    }
    return cJSON_CreateString(raw);
}

static char *do_request(const char *method, const char *url, const char *body)
{
    CURL *curl;
    struct curl_buf buf = {0};
    long code = 0;

    curl = curl_easy_init();
    if (!curl) {
        return coreauto_transport_error("curl init failed");
    }
    curl_easy_setopt(curl, CURLOPT_URL, url);
    curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, method);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curl_write);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &buf);
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, 60L);
    struct curl_slist *hdrs = NULL;
    if (body) {
        hdrs = curl_slist_append(hdrs, "Content-Type: application/json");
        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, body);
    }
    if (hdrs) {
        curl_easy_setopt(curl, CURLOPT_HTTPHEADER, hdrs);
    }
    CURLcode rc = curl_easy_perform(curl);
    if (rc != CURLE_OK) {
        char *err = coreauto_transport_error(curl_easy_strerror(rc));
        curl_slist_free_all(hdrs);
        curl_easy_cleanup(curl);
        free(buf.data);
        return err;
    }
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &code);
    curl_slist_free_all(hdrs);
    curl_easy_cleanup(curl);

    cJSON *parsed = parse_body(buf.data);
    cJSON *root = cJSON_CreateObject();
    cJSON_AddNumberToObject(root, "status_code", (int)code);
    if (code >= 400) {
        cJSON_AddItemToObject(root, "error", parsed);
    } else {
        cJSON_AddItemToObject(root, "body", parsed);
    }
    char *out = cJSON_PrintUnformatted(root);
    cJSON_Delete(root);
    free(buf.data);
    return out;
}

char *http_get(const char *url)
{
    return do_request("GET", url, NULL);
}

char *http_post_json(const char *url, const char *json_body)
{
    return do_request("POST", url, json_body);
}

char *http_put_json(const char *url, const char *json_body)
{
    return do_request("PUT", url, json_body);
}

char *http_delete(const char *url)
{
    return do_request("DELETE", url, NULL);
}
