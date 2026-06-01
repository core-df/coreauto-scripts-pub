#include "../include/sqsclient.h"
#include "coreauto_result.h"
#include "queue_util.h"

static int aws_configured(void)
{
    return env_nonempty("AWS_ACCESS_KEY_ID") || env_nonempty("AWS_PROFILE");
}

char *sqs_init(void)
{
    if (!aws_configured()) {
        return coreauto_missing_env("AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY or AWS_PROFILE");
    }
    if (!env_nonempty("SQS_QUEUE_URL")) {
        return coreauto_missing_env("SQS_QUEUE_URL (or pass queue_url per call)");
    }
    return queue_ok200();
}
