#include "../include/natsclient.h"
#include "coreauto_result.h"
#include "queue_util.h"

char *nats_init(void)
{
    if (!env_nonempty("NATS_URL") && !env_nonempty("NATS_SERVERS")) {
        return coreauto_missing_env("NATS_URL or NATS_SERVERS");
    }
    return queue_ok200();
}
