#include "../include/redisclient.h"
#include "coreauto_result.h"
#include "queue_util.h"

char *redis_init(void)
{
    if (!env_nonempty("REDIS_URL") && !env_nonempty("REDIS_HOST")) {
        return coreauto_missing_env("REDIS_URL or REDIS_HOST");
    }
    return queue_ok200();
}
