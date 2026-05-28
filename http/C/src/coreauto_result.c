/*
 * Copyright Core DF — Apache License 2.0
 */

#include "../include/coreauto_result.h"

#include <cJSON.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void coreauto_json_free(char *json)
{
    free(json);
}

static char *result_json(int status_code, cJSON *body, cJSON *error)
{
    cJSON *root = cJSON_CreateObject();
    cJSON_AddNumberToObject(root, "status_code", status_code);
    if (body) {
        cJSON_AddItemToObject(root, "body", body);
    }
    if (error) {
        cJSON_AddItemToObject(root, "error", error);
    }
    char *out = cJSON_PrintUnformatted(root);
    cJSON_Delete(root);
    return out;
}

char *coreauto_missing_env(const char *vars)
{
    char msg[256];
    snprintf(msg, sizeof(msg), "Environment variables %s should be defined", vars ? vars : "");
    return result_json(601, NULL, cJSON_CreateString(msg));
}

char *coreauto_transport_error(const char *message)
{
    return result_json(0, NULL, cJSON_CreateString(message ? message : "inaccessible"));
}
