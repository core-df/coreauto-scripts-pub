/*
 * Copyright Core DF — Apache License 2.0
 */
#ifndef COREAUTO_QUEUE_UTIL_H
#define COREAUTO_QUEUE_UTIL_H

#include <cJSON.h>
#include <stdlib.h>

static inline char *queue_ok200(void)
{
    cJSON *r = cJSON_CreateObject();
    char *out;
    cJSON_AddNumberToObject(r, "status_code", 200);
    out = cJSON_PrintUnformatted(r);
    cJSON_Delete(r);
    return out;
}

static inline const char *env_nonempty(const char *name)
{
    const char *v = getenv(name);
    return (v && v[0]) ? v : NULL;
}

#endif /* COREAUTO_QUEUE_UTIL_H */
