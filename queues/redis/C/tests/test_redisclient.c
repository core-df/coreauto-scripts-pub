#include "../../../../tests/c/testutil.h"
#include "../include/redisclient.h"
#include <stdlib.h>

TEST(test_init_missing)
{
    unsetenv_safe("REDIS_URL");
    unsetenv_safe("REDIS_HOST");
    char *json = redis_init();
    ASSERT("601", json_status(json) == 601);
    free(json);
}

TEST(test_init_ok)
{
    setenv("REDIS_HOST", "redis.local", 1);
    char *json = redis_init();
    ASSERT("200", json_status(json) == 200);
    free(json);
}

int main(void)
{
    RUN(test_init_missing);
    RUN(test_init_ok);
    printf("redis C tests passed\n");
    return 0;
}
