/*
 * Copyright Core DF — Apache License 2.0
 */
#include "../include/ingressclient.h"
#include "coreauto_result.h"
#include "queue_util.h"

#include "cawbsingress.h"
#include "wbs.h"

#include <cJSON.h>
#include <stdlib.h>
#include <string.h>

static const char *event_name_or_env(const char *event_name)
{
    if (event_name && event_name[0]) {
        return event_name;
    }
    return env_nonempty("CA_EVENT_NAME");
}

static char *wbs_result_to_json(wbs_result r)
{
    cJSON *root = cJSON_CreateObject();
    char *out;
    cJSON_AddNumberToObject(root, "status_code", r.status_code);
    if (r.error) {
        cJSON *err = cJSON_Parse(r.error);
        if (err) {
            cJSON_AddItemToObject(root, "error", err);
        } else {
            cJSON_AddStringToObject(root, "error", r.error);
        }
    }
    if (r.answer) {
        cJSON *ans = cJSON_Parse(r.answer);
        if (ans) {
            cJSON *aid = cJSON_GetObjectItem(ans, "actionId");
            cJSON *eid = cJSON_GetObjectItem(ans, "eventId");
            if (cJSON_IsNumber(aid)) {
                cJSON_AddNumberToObject(root, "actionId", aid->valueint);
            }
            if (cJSON_IsNumber(eid)) {
                cJSON_AddNumberToObject(root, "eventId", eid->valueint);
            }
            cJSON_Delete(ans);
        }
    }
    out = cJSON_PrintUnformatted(root);
    cJSON_Delete(root);
    return out;
}

char *ingress_trigger_event(const char *payload_json, const char *event_name,
                            const char *event_source)
{
    const char *name = event_name_or_env(event_name);
    wbs_result init;
    wbs_result post;
    const char *source;

    if (!name) {
        return coreauto_missing_env("CA_EVENT_NAME (or pass event_name)");
    }

    init = cawbsingress_init();
    if (init.status_code >= 400) {
        char *out = wbs_result_to_json(init);
        wbs_result_free(&init);
        return out;
    }
    wbs_result_free(&init);

    source = (event_source && event_source[0]) ? event_source : env_nonempty("CA_EVENT_SOURCE");
    if (source) {
        post = cawbsingress_post_event(name, payload_json, source);
    } else {
        post = cawbsingress_post_event(name, payload_json, NULL);
    }
    {
        char *out = wbs_result_to_json(post);
        wbs_result_free(&post);
        return out;
    }
}

char *ingress_forward_messages(const char *consume_json)
{
    cJSON *root;
    cJSON *sc;
    int code;

    if (!consume_json) {
        return coreauto_transport_error("missing consume result");
    }
    root = cJSON_Parse(consume_json);
    if (!root) {
        return coreauto_transport_error("invalid consume json");
    }
    sc = cJSON_GetObjectItem(root, "status_code");
    code = cJSON_IsNumber(sc) ? sc->valueint : 0;
    if (code != 200) {
        cJSON *err = cJSON_GetObjectItem(root, "error");
        char *out;
        cJSON *r = cJSON_CreateObject();
        cJSON_AddNumberToObject(r, "status_code", code);
        if (err) {
            cJSON_AddItemToObject(r, "error", cJSON_Duplicate(err, 1));
        }
        out = cJSON_PrintUnformatted(r);
        cJSON_Delete(r);
        cJSON_Delete(root);
        return out;
    }
    cJSON_Delete(root);
    return queue_ok200();
}
