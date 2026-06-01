/*
 * Copyright Core DF — Apache License 2.0
 */

#include "../../../tests/c/mock_http.h"
#include "../../../tests/c/testutil.h"
#include "../include/wbs.h"

#include <stdlib.h>
#include <string.h>

static char g_base_url[128];

static void setup_mock_env(void)
{
    char url[256];
    snprintf(url, sizeof(url), "%s/", g_base_url);
    setenv("ENV", "DEV", 1);
    setenv("CA_ACCESS_CODE", "code", 1);
    setenv("CA_WBS_URL", url, 1);
    setenv("ACTIONID", "99", 1);
    setenv("STEPNAME", "step1", 1);
}

TEST(test_missing_env)
{
    wbs_result r = wbs_missing_env("ENV, CA_WBS_URL");
    ASSERT("status 601", r.status_code == 601);
    ASSERT("error set", r.error != NULL);
    wbs_result_free(&r);
}

TEST(test_authenticate_and_event_payload)
{
    wbs_session *s = wbs_session_new();
    wbs_result r;

    setup_mock_env();
    r = wbs_authenticate(s, "DEV", "code", g_base_url);
    ASSERT("auth 200", r.status_code == 200);
    wbs_result_free(&r);

    r = wbs_get_event_payload(s, "99");
    ASSERT("payload 200", r.status_code == 200);
    ASSERT("payload present", r.payload != NULL && strstr(r.payload, "orderId") != NULL);
    wbs_result_free(&r);

    r = wbs_get_keystore(s, "db_user");
    ASSERT("keystore 200", r.status_code == 200);
    wbs_result_free(&r);

    wbs_session_free(s);
}

TEST(test_init_required)
{
    wbs_session *s = wbs_session_new();
    wbs_result r = wbs_get_event_payload(s, "1");
    ASSERT("603 before init", r.status_code == 603);
    wbs_result_free(&r);
    wbs_session_free(s);
}

TEST(test_double_init)
{
    wbs_session *s = wbs_session_new();
    wbs_result r;

    setup_mock_env();
    r = wbs_authenticate(s, "DEV", "code", g_base_url);
    ASSERT("first auth", r.status_code == 200);
    wbs_result_free(&r);

    r = wbs_authenticate(s, "DEV", "code", g_base_url);
    ASSERT("602 second auth", r.status_code == 602);
    wbs_result_free(&r);
    wbs_session_free(s);
}

int main(void)
{
    if (mock_http_start(g_base_url, sizeof(g_base_url)) != 0) {
        fprintf(stderr, "mock_http_start failed\n");
        return 1;
    }

    RUN(test_missing_env);
    RUN(test_init_required);
    RUN(test_authenticate_and_event_payload);
    RUN(test_double_init);

    mock_http_stop();
    printf("cawbs wbs tests passed\n");
    return 0;
}
