/*
 * Copyright Core DF — Apache License 2.0
 */

#include "../../../tests/c/mock_http.h"
#include "../../../tests/c/testutil.h"
#include "../include/httpclient.h"
#include "../include/coreauto_result.h"

#include <stdio.h>
#include <string.h>

static char g_base_url[128];

TEST(test_get_success)
{
    char url[256];
    char *json;

    snprintf(url, sizeof(url), "%s/items", g_base_url);
    json = http_get(url);
    ASSERT("get 200", json_status(json) == 200);
    coreauto_json_free(json);
}

TEST(test_post_json)
{
    char url[256];
    char *json;

    snprintf(url, sizeof(url), "%s/items", g_base_url);
    json = http_post_json(url, "{\"name\":\"x\"}");
    ASSERT("post 200", json_status(json) == 200);
    coreauto_json_free(json);
}

TEST(test_bad_url_transport)
{
    char *json = http_get("http://127.0.0.1:1/nope");
    ASSERT("transport 0", json_status(json) == 0);
    coreauto_json_free(json);
}

int main(void)
{
    if (mock_http_start(g_base_url, sizeof(g_base_url)) != 0) {
        fprintf(stderr, "mock_http_start failed\n");
        return 1;
    }

    RUN(test_get_success);
    RUN(test_post_json);
    mock_http_stop();

    RUN(test_bad_url_transport);
    printf("http tests passed\n");
    return 0;
}
