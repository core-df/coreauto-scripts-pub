/*
 * Copyright Core DF — Apache License 2.0
 */

#include "../../../tests/c/mock_http.h"
#include "../../../tests/c/testutil.h"
#include "../include/cawbs.h"
#include "../include/cawbsbatch.h"
#include "../include/cawbsingress.h"

#include <stdlib.h>
#include <string.h>

static char g_base_url[128];

static void clear_rt_env(void)
{
    unsetenv_safe("ENV");
    unsetenv_safe("ACTIONID");
    unsetenv_safe("CA_ACCESS_CODE");
    unsetenv_safe("CA_WBS_URL");
    unsetenv_safe("STEPNAME");
}

static void set_rt_env(void)
{
    char url[256];
    snprintf(url, sizeof(url), "%s/", g_base_url);
    setenv("ENV", "DEV", 1);
    setenv("ACTIONID", "99", 1);
    setenv("CA_ACCESS_CODE", "code", 1);
    setenv("CA_WBS_URL", url, 1);
    setenv("STEPNAME", "step1", 1);
}

TEST(test_cawbs_init_missing_env)
{
    clear_rt_env();
    wbs_result r = cawbs_init();
    ASSERT("601 missing env", r.status_code == 601);
    wbs_result_free(&r);
}

TEST(test_cawbs_init_success)
{
    set_rt_env();
    wbs_result r = cawbs_init();
    ASSERT("init 200", r.status_code == 200);
    wbs_result_free(&r);

    r = cawbs_get_event_payload();
    ASSERT("event 200", r.status_code == 200);
    wbs_result_free(&r);
}

TEST(test_cawbsbatch_missing_env)
{
    unsetenv_safe("ENV");
    unsetenv_safe("CA_ACCESS_CODE");
    unsetenv_safe("CA_WBS_URL");
    wbs_result r = cawbsbatch_init();
    ASSERT("batch 601", r.status_code == 601);
    wbs_result_free(&r);
}

TEST(test_cawbsingress_missing_env)
{
    unsetenv_safe("ENV");
    unsetenv_safe("CA_ACCESS_CODE");
    unsetenv_safe("CA_WBS_URL");
    wbs_result r = cawbsingress_init();
    ASSERT("ingress 601", r.status_code == 601);
    wbs_result_free(&r);
}

int main(void)
{
    if (mock_http_start(g_base_url, sizeof(g_base_url)) != 0) {
        fprintf(stderr, "mock_http_start failed\n");
        return 1;
    }

    RUN(test_cawbs_init_missing_env);
    RUN(test_cawbs_init_success);
    RUN(test_cawbsbatch_missing_env);
    RUN(test_cawbsingress_missing_env);

    mock_http_stop();
    printf("cawbs package tests passed\n");
    return 0;
}
