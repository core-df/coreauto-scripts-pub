#include "../../../../tests/c/testutil.h"
#include "../include/ibmmqclient.h"
#include <stdlib.h>

TEST(test_init_missing)
{
    unsetenv_safe("MQ_HOST");
    char *json = ibmmq_init();
    ASSERT("601", json_status(json) == 601);
    free(json);
}

TEST(test_init_ok)
{
    setenv("MQ_HOST", "mq.local", 1);
    setenv("MQ_QUEUE_MANAGER", "QM1", 1);
    setenv("MQ_QUEUE", "Q1", 1);
    char *json = ibmmq_init();
    ASSERT("200", json_status(json) == 200);
    free(json);
}

int main(void)
{
    RUN(test_init_missing);
    RUN(test_init_ok);
    printf("ibmmq C tests passed\n");
    return 0;
}
