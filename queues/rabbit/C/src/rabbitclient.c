#include "../include/rabbitclient.h"
#include "coreauto_result.h"
#include "queue_util.h"

static int rabbit_configured(void)
{
    return env_nonempty("RABBITMQ_URL") || env_nonempty("RABBITMQ_HOST");
}

char *rabbit_init(void)
{
    if (!rabbit_configured()) {
        return coreauto_missing_env("RABBITMQ_URL or RABBITMQ_HOST");
    }
    return queue_ok200();
}
