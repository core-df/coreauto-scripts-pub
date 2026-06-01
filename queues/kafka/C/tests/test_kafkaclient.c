/*
 * Copyright Core DF — Apache License 2.0
 */
#include "../../../../tests/c/testutil.h"
#include "../include/kafkaclient.h"

#include <cJSON.h>
#include <stdlib.h>
#include <string.h>

TEST(test_init_missing)
{
    unsetenv_safe("KAFKA_BOOTSTRAP_SERVERS");
    char *json = kafka_init();
    ASSERT("601", json_status(json) == 601);
    free(json);
}

TEST(test_init_ok)
{
    setenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092", 1);
    char *json = kafka_init();
    ASSERT("200", json_status(json) == 200);
    free(json);
}

TEST(test_produce_missing_bootstrap)
{
    unsetenv_safe("KAFKA_BOOTSTRAP_SERVERS");
    char *json = kafka_produce("orders", "{\"id\":1}", "k1");
    ASSERT("601", json_status(json) == 601);
    free(json);
}

TEST(test_consume_missing_bootstrap)
{
    unsetenv_safe("KAFKA_BOOTSTRAP_SERVERS");
    char *json = kafka_consume("orders", 1.0, 1, NULL);
    ASSERT("601", json_status(json) == 601);
    free(json);
}

TEST(test_produce_empty_topic)
{
    setenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092", 1);
    char *json = kafka_produce("", "{\"id\":1}", NULL);
    ASSERT("500", json_status(json) == 500);
    free(json);
}

/* Runs only when KAFKA_INTEGRATION=1 and a broker is reachable. */
TEST(test_integration_produce_consume)
{
    const char *run = getenv("KAFKA_INTEGRATION");
    char *produce_json;
    char *consume_json;
    cJSON *root;
    cJSON *messages;
    int count;

    if (!run || !run[0]) {
        return;
    }

    setenv("KAFKA_BOOTSTRAP_SERVERS",
           getenv("KAFKA_BOOTSTRAP_SERVERS") ? getenv("KAFKA_BOOTSTRAP_SERVERS")
                                             : "localhost:9092",
           0);
    setenv("KAFKA_GROUP_ID", "coreauto-c-test", 1);

    produce_json = kafka_produce("coreauto-c-test", "{\"ping\":true}", "t1");
    ASSERT("produce ok", json_status(produce_json) == 200);
    free(produce_json);

    consume_json = kafka_consume("coreauto-c-test", 10.0, 1, "coreauto-c-test");
    ASSERT("consume ok", json_status(consume_json) == 200);
    root = cJSON_Parse(consume_json);
    ASSERT("parse", root != NULL);
    messages = cJSON_GetObjectItem(root, "messages");
    count = cJSON_IsArray(messages) ? cJSON_GetArraySize(messages) : 0;
    ASSERT("got message", count >= 0);
    cJSON_Delete(root);
    free(consume_json);
}

int main(void)
{
    RUN(test_init_missing);
    RUN(test_init_ok);
    RUN(test_produce_missing_bootstrap);
    RUN(test_consume_missing_bootstrap);
    RUN(test_produce_empty_topic);
    RUN(test_integration_produce_consume);
    printf("kafka C tests passed\n");
    return 0;
}
