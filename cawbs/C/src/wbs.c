/*
 * Copyright Core DF
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * Shared HTTP helpers for the Core Auto Collector (cawbs) C client.
 */

#include "wbs.h"

#include <curl/curl.h>
#if defined(__has_include)
#if __has_include(<cjson/cJSON.h>)
#include <cjson/cJSON.h>
#elif __has_include(<cJSON.h>)
#include <cJSON.h>
#else
#error "libcjson required (cJSON.h)"
#endif
#else
#include <cJSON.h>
#endif
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct wbs_session {
    int initialized;
    char *base_url;
    char *env;
    char *token;
};

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

static char *wbs_strdup(const char *s)
{
    size_t n;
    char *p;
    if (!s) {
        return NULL;
    }
    n = strlen(s);
    p = (char *)malloc(n + 1);
    if (!p) {
        return NULL;
    }
    memcpy(p, s, n + 1);
    return p;
}

static char *wbs_trim_url(const char *url)
{
    const char *start = url;
    const char *end;
    size_t len;
    char *out;
    if (!url) {
        return NULL;
    }
    while (*start == '/' || *start == ' ') {
        start++;
    }
    end = start + strlen(start);
    while (end > start && (end[-1] == '/' || end[-1] == ' ')) {
        end--;
    }
    len = (size_t)(end - start);
    out = (char *)malloc(len + 1);
    if (!out) {
        return NULL;
    }
    memcpy(out, start, len);
    out[len] = '\0';
    return out;
}

static wbs_result wbs_ok(int status_code)
{
    wbs_result r = {0};
    r.status_code = status_code;
    return r;
}

static wbs_result wbs_err(int status_code, const char *msg)
{
    wbs_result r = {0};
    r.status_code = status_code;
    r.error = wbs_strdup(msg ? msg : "inaccessible");
    return r;
}

static wbs_result wbs_err_json(int status_code, cJSON *json)
{
    wbs_result r = {0};
    char *s;
    r.status_code = status_code;
    s = cJSON_PrintUnformatted(json);
    r.error = s ? s : wbs_strdup("inaccessible");
    return r;
}

void wbs_result_free(wbs_result *result)
{
    if (!result) {
        return;
    }
    free(result->error);
    free(result->payload);
    free(result->answer);
    result->error = NULL;
    result->payload = NULL;
    result->answer = NULL;
}

wbs_session *wbs_session_new(void)
{
    wbs_session *s = (wbs_session *)calloc(1, sizeof(*s));
    return s;
}

void wbs_session_free(wbs_session *session)
{
    if (!session) {
        return;
    }
    free(session->base_url);
    free(session->env);
    free(session->token);
    free(session);
}

wbs_result wbs_missing_env(const char *vars)
{
    char buf[512];
    snprintf(buf, sizeof(buf), "Environment variables %s should be defined", vars);
    return wbs_err(601, buf);
}

static int wbs_request(wbs_session *session, const char *method, const char *url,
                       const char *body, long *http_code, char **resp_body)
{
    CURL *curl;
    struct curl_buf buf = {0};
    struct curl_slist *headers = NULL;
    char hdr_env[512];
    char hdr_auth[1024];

    *http_code = 0;
    *resp_body = NULL;

    curl = curl_easy_init();
    if (!curl) {
        return -1;
    }

    snprintf(hdr_env, sizeof(hdr_env), "Environment: %s", session->env);
    headers = curl_slist_append(headers, "Content-Type: application/json");
    headers = curl_slist_append(headers, hdr_env);
    if (session->token && session->token[0]) {
        snprintf(hdr_auth, sizeof(hdr_auth), "Authorization: Bearer %s", session->token);
        headers = curl_slist_append(headers, hdr_auth);
    }

    curl_easy_setopt(curl, CURLOPT_URL, url);
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, curl_write);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA, &buf);
    curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, method);
    if (body) {
        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, body);
    }

    if (curl_easy_perform(curl) != CURLE_OK) {
        curl_slist_free_all(headers);
        curl_easy_cleanup(curl);
        free(buf.data);
        return -1;
    }

    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, http_code);
    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);
    *resp_body = buf.data;
    return 0;
}

wbs_result wbs_authenticate(wbs_session *session, const char *env,
                            const char *access_code, const char *base_url)
{
    wbs_result r;
    long code;
    char *body = NULL;
    char url[2048];
    cJSON *resp;
    cJSON *token;

    if (session->initialized) {
        return wbs_err(602, "init already called");
    }

    free(session->env);
    free(session->base_url);
    session->env = wbs_strdup(env);
    session->base_url = wbs_trim_url(base_url);

    {
        cJSON *req = cJSON_CreateObject();
        char *todo_local;
        cJSON_AddStringToObject(req, "apiCode", access_code);
        todo_local = cJSON_PrintUnformatted(req);
        cJSON_Delete(req);
        if (!todo_local) {
            return wbs_err(500, "inaccessible");
        }
        snprintf(url, sizeof(url), "%s/v1/auth/apicode", session->base_url);
        if (wbs_request(session, "POST", url, todo_local, &code, &body) != 0) {
            free(todo_local);
            return wbs_err(0, "inaccessible");
        }
        free(todo_local);
    }

    if (code >= 400) {
        resp = cJSON_Parse(body);
        free(body);
        if (!resp) {
            return wbs_err((int)code, "inaccessible");
        }
        r = wbs_err_json((int)code, resp);
        cJSON_Delete(resp);
        return r;
    }

    resp = cJSON_Parse(body);
    free(body);
    if (!resp) {
        return wbs_err((int)code, "inaccessible");
    }
    token = cJSON_GetObjectItem(resp, "token");
    if (!cJSON_IsString(token) || !token->valuestring) {
        cJSON_Delete(resp);
        return wbs_err((int)code, "inaccessible");
    }
    free(session->token);
    session->token = wbs_strdup(token->valuestring);
    cJSON_Delete(resp);
    session->initialized = 1;
    return wbs_ok((int)code);
}

wbs_result wbs_get_event_payload(wbs_session *session, const char *action_id)
{
    wbs_result r;
    long code;
    char *body = NULL;
    char url[2048];
    cJSON *resp;
    cJSON *payload;
    char *payload_str;

    if (!session->initialized) {
        return wbs_err(603, "Init required");
    }

    snprintf(url, sizeof(url), "%s/v1/rtevent/%s", session->base_url, action_id);
    if (wbs_request(session, "GET", url, NULL, &code, &body) != 0) {
        return wbs_err(0, "inaccessible");
    }
    if (code >= 400) {
        resp = cJSON_Parse(body);
        free(body);
        if (!resp) {
            return wbs_err((int)code, "inaccessible");
        }
        r = wbs_err_json((int)code, resp);
        cJSON_Delete(resp);
        return r;
    }

    resp = cJSON_Parse(body);
    free(body);
    if (!resp) {
        return wbs_err((int)code, "inaccessible");
    }
    payload = cJSON_GetObjectItem(resp, "payload");
    payload_str = cJSON_PrintUnformatted(payload);
    cJSON_Delete(resp);
    if (!payload_str) {
        return wbs_err((int)code, "inaccessible");
    }
    r = wbs_ok((int)code);
    r.payload = payload_str;
    return r;
}

wbs_result wbs_put_step_payload(wbs_session *session, const char *action_id,
                                const char *step_name, const char *payload_json)
{
    wbs_result r;
    long code;
    char *body = NULL;
    char url[2048];
    char *todo = NULL;
    cJSON *resp;
    cJSON *root;
    cJSON *payload;

    if (!session->initialized) {
        return wbs_err(603, "Init required");
    }

    payload = cJSON_Parse(payload_json);
    if (!payload) {
        return wbs_err(500, "invalid payload JSON");
    }
    root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "actionId", action_id);
    cJSON_AddStringToObject(root, "stepname", step_name);
    cJSON_AddItemToObject(root, "payload", payload);
    todo = cJSON_PrintUnformatted(root);
    cJSON_Delete(root);
    if (!todo) {
        return wbs_err(500, "inaccessible");
    }

    snprintf(url, sizeof(url), "%s/v1/rtstep/payload", session->base_url);
    if (wbs_request(session, "POST", url, todo, &code, &body) != 0) {
        free(todo);
        return wbs_err(0, "inaccessible");
    }
    free(todo);

    if (code >= 400) {
        resp = cJSON_Parse(body);
        free(body);
        if (!resp) {
            return wbs_err((int)code, "inaccessible");
        }
        r = wbs_err_json((int)code, resp);
        cJSON_Delete(resp);
        return r;
    }
    free(body);
    return wbs_ok((int)code);
}

wbs_result wbs_get_step_payload(wbs_session *session, const char *action_id,
                                const char *step_name)
{
    wbs_result r;
    long code;
    char *body = NULL;
    char url[2048];
    cJSON *resp;
    cJSON *payload;
    char *payload_str;

    if (!session->initialized) {
        return wbs_err(603, "Init required");
    }

    snprintf(url, sizeof(url), "%s/v1/rtstep/payload/%s/%s", session->base_url,
             action_id, step_name);
    if (wbs_request(session, "GET", url, NULL, &code, &body) != 0) {
        return wbs_err(0, "inaccessible");
    }
    if (code >= 400) {
        resp = cJSON_Parse(body);
        free(body);
        if (!resp) {
            return wbs_err((int)code, "inaccessible");
        }
        r = wbs_err_json((int)code, resp);
        cJSON_Delete(resp);
        return r;
    }

    resp = cJSON_Parse(body);
    free(body);
    if (!resp) {
        return wbs_err((int)code, "inaccessible");
    }
    payload = cJSON_GetObjectItem(resp, "payload");
    payload_str = cJSON_PrintUnformatted(payload);
    cJSON_Delete(resp);
    if (!payload_str) {
        return wbs_err((int)code, "inaccessible");
    }
    r = wbs_ok((int)code);
    r.payload = payload_str;
    return r;
}

wbs_result wbs_get_keystore(wbs_session *session, const char *keylist)
{
    wbs_result r;
    long code;
    char *body = NULL;
    char url[2048];
    char keys[1024];
    cJSON *resp;
    char *answer_str;
    const char *p;
    char key[256];
    size_t i, j;

    if (!session->initialized) {
        return wbs_err(603, "Init required");
    }

    j = 0;
    for (i = 0; keylist[i] && j + 1 < sizeof(keys); i++) {
        if (keylist[i] != ' ') {
            keys[j++] = keylist[i];
        }
    }
    keys[j] = '\0';

    snprintf(url, sizeof(url), "%s/v1/keystore/%s", session->base_url, keys);
    if (wbs_request(session, "GET", url, NULL, &code, &body) != 0) {
        return wbs_err(0, "inaccessible");
    }
    if (code >= 400) {
        resp = cJSON_Parse(body);
        free(body);
        if (!resp) {
            return wbs_err((int)code, "inaccessible");
        }
        r = wbs_err_json((int)code, resp);
        cJSON_Delete(resp);
        return r;
    }

    resp = cJSON_Parse(body);
    free(body);
    if (!resp) {
        return wbs_err((int)code, "inaccessible");
    }

    p = keys;
    while (*p) {
        i = 0;
        while (*p && *p != ',' && i + 1 < sizeof(key)) {
            key[i++] = *p++;
        }
        key[i] = '\0';
        if (*p == ',') {
            p++;
        }
        if (key[0] && !cJSON_GetObjectItem(resp, key)) {
            char msg[300];
            snprintf(msg, sizeof(msg), "%s not found", key);
            cJSON_Delete(resp);
            return wbs_err(605, msg);
        }
    }

    answer_str = cJSON_PrintUnformatted(resp);
    cJSON_Delete(resp);
    if (!answer_str) {
        return wbs_err((int)code, "inaccessible");
    }
    r = wbs_ok((int)code);
    r.answer = answer_str;
    return r;
}

static wbs_result wbs_ok_json_body(int status_code, cJSON *resp)
{
    wbs_result r;
    char *s;

    s = cJSON_PrintUnformatted(resp);
    if (!s) {
        return wbs_err(status_code, "inaccessible");
    }
    r = wbs_ok(status_code);
    r.payload = s;
    return r;
}

wbs_result wbs_post_event(wbs_session *session, const char *event_name,
                          const char *payload_json, const char *event_source)
{
    wbs_result r;
    long code;
    char *body = NULL;
    char url[2048];
    char *todo = NULL;
    cJSON *resp;
    cJSON *root;
    cJSON *payload;

    if (!session->initialized) {
        return wbs_err(603, "Init required");
    }

    payload = cJSON_Parse(payload_json);
    if (!payload) {
        return wbs_err(500, "invalid payload JSON");
    }
    root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "eventName", event_name);
    cJSON_AddItemToObject(root, "payload", payload);
    if (event_source && event_source[0]) {
        cJSON_AddStringToObject(root, "eventSource", event_source);
    }
    todo = cJSON_PrintUnformatted(root);
    cJSON_Delete(root);
    if (!todo) {
        return wbs_err(500, "inaccessible");
    }

    snprintf(url, sizeof(url), "%s/v1/rtevent", session->base_url);
    if (wbs_request(session, "POST", url, todo, &code, &body) != 0) {
        free(todo);
        return wbs_err(0, "inaccessible");
    }
    free(todo);

    if (code >= 400) {
        resp = cJSON_Parse(body);
        free(body);
        if (!resp) {
            return wbs_err((int)code, "inaccessible");
        }
        r = wbs_err_json((int)code, resp);
        cJSON_Delete(resp);
        return r;
    }

    resp = cJSON_Parse(body);
    free(body);
    if (!resp) {
        return wbs_err((int)code, "inaccessible");
    }
    r = wbs_ok_json_body((int)code, resp);
    cJSON_Delete(resp);
    return r;
}

wbs_result wbs_get_event_status(wbs_session *session, const char *action_id)
{
    wbs_result r;
    long code;
    char *body = NULL;
    char url[2048];
    cJSON *resp;

    if (!session->initialized) {
        return wbs_err(603, "Init required");
    }

    snprintf(url, sizeof(url), "%s/v1/rtevent/status/%s", session->base_url, action_id);
    if (wbs_request(session, "GET", url, NULL, &code, &body) != 0) {
        return wbs_err(0, "inaccessible");
    }
    if (code >= 400) {
        resp = cJSON_Parse(body);
        free(body);
        if (!resp) {
            return wbs_err((int)code, "inaccessible");
        }
        r = wbs_err_json((int)code, resp);
        cJSON_Delete(resp);
        return r;
    }

    resp = cJSON_Parse(body);
    free(body);
    if (!resp) {
        return wbs_err((int)code, "inaccessible");
    }
    r = wbs_ok_json_body((int)code, resp);
    cJSON_Delete(resp);
    return r;
}

wbs_result wbs_get_event_list(wbs_session *session)
{
    wbs_result r;
    long code;
    char *body = NULL;
    char url[2048];
    cJSON *resp;

    if (!session->initialized) {
        return wbs_err(603, "Init required");
    }

    snprintf(url, sizeof(url), "%s/v1/rtevent/list", session->base_url);
    if (wbs_request(session, "GET", url, NULL, &code, &body) != 0) {
        return wbs_err(0, "inaccessible");
    }
    if (code >= 400) {
        resp = cJSON_Parse(body);
        free(body);
        if (!resp) {
            return wbs_err((int)code, "inaccessible");
        }
        r = wbs_err_json((int)code, resp);
        cJSON_Delete(resp);
        return r;
    }

    resp = cJSON_Parse(body);
    free(body);
    if (!resp) {
        return wbs_err((int)code, "inaccessible");
    }
    r = wbs_ok_json_body((int)code, resp);
    cJSON_Delete(resp);
    return r;
}

wbs_result wbs_submit_flag(wbs_session *session, const char *name,
                           const char *system_name, const char *source_system_name,
                           const char *date)
{
    wbs_result r;
    long code;
    char *body = NULL;
    char url[2048];
    char *todo = NULL;
    cJSON *resp;
    cJSON *root;

    if (!session->initialized) {
        return wbs_err(603, "Init required");
    }

    root = cJSON_CreateObject();
    cJSON_AddStringToObject(root, "name", name);
    cJSON_AddStringToObject(root, "systemName", system_name);
    cJSON_AddStringToObject(root, "sourceSystemName", source_system_name);
    cJSON_AddStringToObject(root, "date", date);
    todo = cJSON_PrintUnformatted(root);
    cJSON_Delete(root);
    if (!todo) {
        return wbs_err(500, "inaccessible");
    }

    snprintf(url, sizeof(url), "%s/v1/flag", session->base_url);
    if (wbs_request(session, "POST", url, todo, &code, &body) != 0) {
        free(todo);
        return wbs_err(0, "inaccessible");
    }
    free(todo);

    if (code >= 400) {
        resp = cJSON_Parse(body);
        free(body);
        if (!resp) {
            return wbs_err((int)code, "inaccessible");
        }
        r = wbs_err_json((int)code, resp);
        cJSON_Delete(resp);
        return r;
    }

    resp = cJSON_Parse(body);
    free(body);
    if (!resp) {
        return wbs_err((int)code, "inaccessible");
    }
    r = wbs_ok_json_body((int)code, resp);
    cJSON_Delete(resp);
    return r;
}
