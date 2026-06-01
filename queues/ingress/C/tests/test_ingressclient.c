/*
 * Copyright Core DF — Apache License 2.0
 */
#include "../../../../tests/c/testutil.h"
#include "../include/ingressclient.h"

#include <stdlib.h>

TEST(test_trigger_missing_event_name)
{
    unsetenv_safe("CA_EVENT_NAME");
    char *json = ingress_trigger_event("{\"x\":1}", NULL, NULL);
    ASSERT("601", json_status(json) == 601);
    free(json);
}

TEST(test_forward_bad_consume)
{
    char *json = ingress_forward_messages("{\"status_code\":500,\"error\":\"fail\"}");
    ASSERT("500", json_status(json) == 500);
    free(json);
}

TEST(test_forward_ok_empty)
{
    char *json = ingress_forward_messages("{\"status_code\":200,\"messages\":[]}");
    ASSERT("200", json_status(json) == 200);
    free(json);
}

int main(void)
{
    RUN(test_trigger_missing_event_name);
    RUN(test_forward_bad_consume);
    RUN(test_forward_ok_empty);
    printf("ingress C tests passed\n");
    return 0;
}
