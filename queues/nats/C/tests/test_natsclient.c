#include "../../../../tests/c/testutil.h"
#include "../include/natsclient.h"
#include <stdlib.h>

TEST(test_init_missing)
{
    unsetenv_safe("NATS_URL");
    unsetenv_safe("NATS_SERVERS");
    char *json = nats_init();
    ASSERT("601", json_status(json) == 601);
    free(json);
}

TEST(test_init_ok)
{
    setenv("NATS_URL", "nats://localhost:4222", 1);
    char *json = nats_init();
    ASSERT("200", json_status(json) == 200);
    free(json);
}

int main(void)
{
    RUN(test_init_missing);
    RUN(test_init_ok);
    printf("nats C tests passed\n");
    return 0;
}
