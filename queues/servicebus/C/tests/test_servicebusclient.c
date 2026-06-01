#include "../../../../tests/c/testutil.h"
#include "../include/servicebusclient.h"
#include <stdlib.h>

TEST(test_init_missing)
{
    unsetenv_safe("SERVICE_BUS_CONNECTION_STRING");
    char *json = servicebus_init();
    ASSERT("601", json_status(json) == 601);
    free(json);
}

TEST(test_init_ok)
{
    setenv("SERVICE_BUS_CONNECTION_STRING", "Endpoint=sb://x", 1);
    setenv("SERVICE_BUS_QUEUE_NAME", "q1", 1);
    char *json = servicebus_init();
    ASSERT("200", json_status(json) == 200);
    free(json);
}

int main(void)
{
    RUN(test_init_missing);
    RUN(test_init_ok);
    printf("servicebus C tests passed\n");
    return 0;
}
