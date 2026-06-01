#include "../../../../tests/c/testutil.h"
#include "../include/sqsclient.h"
#include <stdlib.h>

TEST(test_init_missing_creds)
{
    unsetenv_safe("AWS_ACCESS_KEY_ID");
    unsetenv_safe("AWS_PROFILE");
    setenv("SQS_QUEUE_URL", "https://sqs.example/q", 1);
    char *json = sqs_init();
    ASSERT("601", json_status(json) == 601);
    free(json);
}

TEST(test_init_ok)
{
    setenv("AWS_ACCESS_KEY_ID", "key", 1);
    setenv("SQS_QUEUE_URL", "https://sqs.example/q", 1);
    char *json = sqs_init();
    ASSERT("200", json_status(json) == 200);
    free(json);
}

int main(void)
{
    RUN(test_init_missing_creds);
    RUN(test_init_ok);
    printf("sqs C tests passed\n");
    return 0;
}
