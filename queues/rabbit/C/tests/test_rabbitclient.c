#include "../../../../tests/c/testutil.h"
#include "../include/rabbitclient.h"
#include <stdlib.h>

TEST(test_init_missing)
{
    unsetenv_safe("RABBITMQ_URL");
    unsetenv_safe("RABBITMQ_HOST");
    char *json = rabbit_init();
    ASSERT("601", json_status(json) == 601);
    free(json);
}

TEST(test_init_ok)
{
    setenv("RABBITMQ_HOST", "rabbit.local", 1);
    char *json = rabbit_init();
    ASSERT("200", json_status(json) == 200);
    free(json);
}

int main(void)
{
    RUN(test_init_missing);
    RUN(test_init_ok);
    printf("rabbit C tests passed\n");
    return 0;
}
