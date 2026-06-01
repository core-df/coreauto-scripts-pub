/*
 * Copyright Core DF — Apache License 2.0
 */

#include "../../../tests/c/mock_http.h"
#include "../../../tests/c/testutil.h"
#include "../include/notifyclient.h"
#include "../../http/C/include/coreauto_result.h"

#include <stdio.h>
#include <string.h>

static char g_base_url[128];

TEST(test_slack_missing_webhook)
{
    unsetenv_safe("SLACK_WEBHOOK_URL");
    char *json = notify_slack("hello", NULL);
    ASSERT("slack 601", json_status(json) == 601);
    coreauto_json_free(json);
}

TEST(test_slack_success)
{
    char url[256];
    char *json;

    snprintf(url, sizeof(url), "%s/hook", g_base_url);
    json = notify_slack("hello", url);
    ASSERT("slack 200", json_status(json) == 200);
    coreauto_json_free(json);
}

TEST(test_teams_missing)
{
    unsetenv_safe("TEAMS_WEBHOOK_URL");
    char *json = notify_teams("hi", NULL);
    ASSERT("teams 601", json_status(json) == 601);
    coreauto_json_free(json);
}

TEST(test_pagerduty_missing)
{
    unsetenv_safe("PAGERDUTY_ROUTING_KEY");
    char *json = notify_pagerduty("sum", NULL, NULL);
    ASSERT("pd 601", json_status(json) == 601);
    coreauto_json_free(json);
}

TEST(test_email_missing_smtp)
{
    unsetenv_safe("SMTP_HOST");
    unsetenv_safe("SMTP_FROM");
    char *json = notify_email("subj", "body", "a@b.c", NULL);
    ASSERT("email 601", json_status(json) == 601);
    coreauto_json_free(json);
}

int main(void)
{
    if (mock_http_start(g_base_url, sizeof(g_base_url)) != 0) {
        fprintf(stderr, "mock_http_start failed\n");
        return 1;
    }

    RUN(test_slack_missing_webhook);
    RUN(test_slack_success);
    RUN(test_teams_missing);
    RUN(test_pagerduty_missing);
    RUN(test_email_missing_smtp);

    mock_http_stop();
    printf("notify tests passed\n");
    return 0;
}
