#include "../../../../tests/c/testutil.h"
#include "../include/pubsubclient.h"
#include <stdlib.h>

TEST(test_init_missing_project)
{
    unsetenv_safe("PUBSUB_PROJECT_ID");
    unsetenv_safe("GOOGLE_CLOUD_PROJECT");
    setenv("PUBSUB_TOPIC_ID", "t1", 1);
    char *json = pubsub_init();
    ASSERT("601", json_status(json) == 601);
    free(json);
}

TEST(test_init_ok)
{
    setenv("PUBSUB_PROJECT_ID", "my-proj", 1);
    setenv("PUBSUB_TOPIC_ID", "t1", 1);
    char *json = pubsub_init();
    ASSERT("200", json_status(json) == 200);
    free(json);
}

int main(void)
{
    RUN(test_init_missing_project);
    RUN(test_init_ok);
    printf("pubsub C tests passed\n");
    return 0;
}
