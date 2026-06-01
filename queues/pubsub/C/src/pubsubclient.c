#include "../include/pubsubclient.h"
#include "coreauto_result.h"
#include "queue_util.h"

static const char *pubsub_project(void)
{
    const char *p = env_nonempty("PUBSUB_PROJECT_ID");
    if (p) {
        return p;
    }
    return env_nonempty("GOOGLE_CLOUD_PROJECT");
}

char *pubsub_init(void)
{
    if (!pubsub_project()) {
        return coreauto_missing_env("PUBSUB_PROJECT_ID or GOOGLE_CLOUD_PROJECT");
    }
    if (!env_nonempty("PUBSUB_TOPIC_ID")) {
        return coreauto_missing_env("PUBSUB_TOPIC_ID");
    }
    return queue_ok200();
}
