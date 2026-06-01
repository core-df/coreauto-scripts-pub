#include "../include/ibmmqclient.h"
#include "coreauto_result.h"
#include "queue_util.h"

char *ibmmq_init(void)
{
    if (!env_nonempty("MQ_HOST") || !env_nonempty("MQ_QUEUE_MANAGER")) {
        return coreauto_missing_env("MQ_HOST and MQ_QUEUE_MANAGER");
    }
    if (!env_nonempty("MQ_QUEUE")) {
        return coreauto_missing_env("MQ_QUEUE (or pass queue per call)");
    }
    return queue_ok200();
}
