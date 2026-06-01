/*
 * Copyright Core DF — Apache License 2.0
 */

#include "../../../tests/c/testutil.h"
#include "../include/s3client.h"
#include <stdlib.h>

TEST(test_init_missing_credentials)
{
    unsetenv_safe("AWS_ACCESS_KEY_ID");
    unsetenv_safe("AWS_PROFILE");
    unsetenv_safe("S3_BUCKET");
    char *json = s3_init();
    ASSERT("init 601", json_status(json) == 601);
    free(json);
}

TEST(test_init_success)
{
    setenv("AWS_ACCESS_KEY_ID", "key", 1);
    setenv("AWS_SECRET_ACCESS_KEY", "secret", 1);
    setenv("S3_BUCKET", "my-bucket", 1);
    char *json = s3_init();
    ASSERT("init 200", json_status(json) == 200);
    free(json);
}

TEST(test_get_object_missing_bucket)
{
    unsetenv_safe("S3_BUCKET");
    char *json = s3_get_object("k", "");
    ASSERT("get 601", json_status(json) == 601);
    free(json);
}

int main(void)
{
    RUN(test_init_missing_credentials);
    RUN(test_init_success);
    RUN(test_get_object_missing_bucket);
    printf("s3 tests passed\n");
    return 0;
}
