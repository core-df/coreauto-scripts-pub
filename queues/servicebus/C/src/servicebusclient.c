#include "../include/servicebusclient.h"
#include "coreauto_result.h"
#include "queue_util.h"

char *servicebus_init(void)
{
    if (!env_nonempty("SERVICE_BUS_CONNECTION_STRING")) {
        return coreauto_missing_env("SERVICE_BUS_CONNECTION_STRING");
    }
    if (!env_nonempty("SERVICE_BUS_QUEUE_NAME")) {
        return coreauto_missing_env("SERVICE_BUS_QUEUE_NAME (or pass queue per call)");
    }
    return queue_ok200();
}
