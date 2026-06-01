/*
 * Copyright Core DF — Apache License 2.0
 * Minimal helpers for coreauto-scripts-pub C unit tests.
 */
#ifndef COREAUTO_TESTUTIL_H
#define COREAUTO_TESTUTIL_H

#include <cJSON.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

extern int g_test_failures;

#define TEST(name) static void name(void)
#define RUN(name)                               \
    do {                                        \
        g_test_failures = 0;                    \
        name();                                 \
        if (g_test_failures != 0) {             \
            fprintf(stderr, "FAILED: %s\n", #name); \
            return 1;                           \
        }                                       \
    } while (0)

#define ASSERT(msg, cond)                                           \
    do {                                                            \
        if (!(cond)) {                                              \
            fprintf(stderr, "  assert failed (%s): %s\n", msg, #cond); \
            g_test_failures++;                                      \
        }                                                           \
    } while (0)

static inline int json_status(const char *json)
{
    cJSON *root;
    cJSON *sc;
    int code = -1;
    if (!json) {
        return -1;
    }
    root = cJSON_Parse(json);
    if (!root) {
        return -1;
    }
    sc = cJSON_GetObjectItem(root, "status_code");
    if (cJSON_IsNumber(sc)) {
        code = sc->valueint;
    }
    cJSON_Delete(root);
    return code;
}

static inline void json_free(char *json)
{
    free(json);
}

static inline void unsetenv_safe(const char *name)
{
#if defined(_POSIX_C_SOURCE) || defined(__APPLE__)
    unsetenv(name);
#else
    (void)name;
#endif
}

#endif /* COREAUTO_TESTUTIL_H */
