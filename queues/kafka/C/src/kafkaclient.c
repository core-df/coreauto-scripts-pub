/*
 * Copyright Core DF — Apache License 2.0
 */
#include "../include/kafkaclient.h"

#include "coreauto_result.h"
#include "queue_util.h"

#include <cJSON.h>
#include <librdkafka/rdkafka.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static char g_dr_err[512];
static volatile int g_dr_failed;

static void dr_msg_cb(rd_kafka_t *rk, const rd_kafka_message_t *rkmessage, void *opaque)
{
    (void)rk;
    (void)opaque;
    if (rkmessage->err) {
        g_dr_failed = 1;
        snprintf(g_dr_err, sizeof(g_dr_err), "%s", rd_kafka_message_errstr(rkmessage));
    }
}

static char *err500(const char *msg)
{
    cJSON *r = cJSON_CreateObject();
    char *out;
    cJSON_AddNumberToObject(r, "status_code", 500);
    cJSON_AddStringToObject(r, "error", msg ? msg : "error");
    out = cJSON_PrintUnformatted(r);
    cJSON_Delete(r);
    return out;
}

static int apply_common_conf(rd_kafka_conf_t *conf, char *errstr, size_t errstr_sz)
{
    const char *bs = getenv("KAFKA_BOOTSTRAP_SERVERS");

    if (rd_kafka_conf_set(conf, "bootstrap.servers", bs ? bs : "", errstr, errstr_sz) !=
        RD_KAFKA_CONF_OK) {
        return -1;
    }
    if (env_nonempty("KAFKA_SECURITY_PROTOCOL")) {
        if (rd_kafka_conf_set(conf, "security.protocol", getenv("KAFKA_SECURITY_PROTOCOL"),
                              errstr, errstr_sz) != RD_KAFKA_CONF_OK) {
            return -1;
        }
    }
    if (env_nonempty("KAFKA_SASL_MECHANISM")) {
        if (rd_kafka_conf_set(conf, "sasl.mechanism", getenv("KAFKA_SASL_MECHANISM"), errstr,
                              errstr_sz) != RD_KAFKA_CONF_OK) {
            return -1;
        }
    }
    if (env_nonempty("KAFKA_SASL_USERNAME")) {
        if (rd_kafka_conf_set(conf, "sasl.username", getenv("KAFKA_SASL_USERNAME"), errstr,
                              errstr_sz) != RD_KAFKA_CONF_OK) {
            return -1;
        }
    }
    if (env_nonempty("KAFKA_SASL_PASSWORD")) {
        if (rd_kafka_conf_set(conf, "sasl.password", getenv("KAFKA_SASL_PASSWORD"), errstr,
                              errstr_sz) != RD_KAFKA_CONF_OK) {
            return -1;
        }
    }
    return 0;
}

static char *encode_payload(const char *value, size_t *out_len)
{
    cJSON *j;
    char *encoded;

    if (!value) {
        value = "";
    }
    j = cJSON_Parse(value);
    if (j) {
        if (cJSON_IsObject(j) || cJSON_IsArray(j)) {
            encoded = cJSON_PrintUnformatted(j);
        } else if (cJSON_IsString(j)) {
            encoded = strdup(j->valuestring);
        } else {
            encoded = cJSON_PrintUnformatted(j);
        }
        cJSON_Delete(j);
        if (!encoded) {
            return NULL;
        }
        *out_len = strlen(encoded);
        return encoded;
    }
    encoded = strdup(value);
    if (!encoded) {
        return NULL;
    }
    *out_len = strlen(encoded);
    return encoded;
}

static cJSON *decode_payload(const void *data, size_t len)
{
    char *tmp;
    cJSON *parsed;

    if (!data || len == 0) {
        return cJSON_CreateNull();
    }
    tmp = malloc(len + 1);
    if (!tmp) {
        return NULL;
    }
    memcpy(tmp, data, len);
    tmp[len] = '\0';
    parsed = cJSON_Parse(tmp);
    if (parsed) {
        free(tmp);
        return parsed;
    }
    return cJSON_CreateString(tmp);
}

char *kafka_init(void)
{
    if (!env_nonempty("KAFKA_BOOTSTRAP_SERVERS")) {
        return coreauto_missing_env("KAFKA_BOOTSTRAP_SERVERS");
    }
    return queue_ok200();
}

char *kafka_produce(const char *topic, const char *value, const char *key)
{
    rd_kafka_conf_t *conf;
    rd_kafka_t *rk;
    char errstr[512];
    char *payload;
    size_t payload_len;
    rd_kafka_resp_err_t err;
    void *key_ptr = NULL;
    size_t key_len = 0;

    if (!env_nonempty("KAFKA_BOOTSTRAP_SERVERS")) {
        return coreauto_missing_env("KAFKA_BOOTSTRAP_SERVERS");
    }
    if (!topic || !topic[0]) {
        return err500("topic required");
    }

    conf = rd_kafka_conf_new();
    if (apply_common_conf(conf, errstr, sizeof(errstr)) != 0) {
        rd_kafka_conf_destroy(conf);
        return coreauto_transport_error(errstr);
    }
    rd_kafka_conf_set_dr_msg_cb(conf, dr_msg_cb);

    rk = rd_kafka_new(RD_KAFKA_PRODUCER, conf, errstr, sizeof(errstr));
    if (!rk) {
        return coreauto_transport_error(errstr);
    }

    payload = encode_payload(value, &payload_len);
    if (!payload) {
        rd_kafka_destroy(rk);
        return coreauto_transport_error("alloc failed");
    }

    if (key && key[0]) {
        key_ptr = (void *)key;
        key_len = strlen(key);
    }

    g_dr_failed = 0;
    g_dr_err[0] = '\0';

    err = rd_kafka_producev(
        rk,
        RD_KAFKA_V_TOPIC(topic),
        RD_KAFKA_V_VALUE(payload, payload_len),
        RD_KAFKA_V_KEY(key_ptr, key_len),
        RD_KAFKA_V_END);

    free(payload);

    if (err) {
        rd_kafka_destroy(rk);
        return coreauto_transport_error(rd_kafka_err2str(err));
    }

    rd_kafka_poll(rk, 0);
    if (rd_kafka_flush(rk, 30000) != 0) {
        rd_kafka_destroy(rk);
        return coreauto_transport_error("produce flush timeout");
    }
    rd_kafka_poll(rk, 0);

    if (g_dr_failed) {
        rd_kafka_destroy(rk);
        return err500(g_dr_err);
    }

    rd_kafka_destroy(rk);
    return queue_ok200();
}

char *kafka_consume(const char *topic, double timeout_sec, int max_messages,
                    const char *group_id)
{
    rd_kafka_conf_t *conf;
    rd_kafka_t *rk;
    char errstr[512];
    const char *gid;
    const char *offset_reset;
    rd_kafka_resp_err_t err;
    rd_kafka_topic_partition_list_t *topics;
    cJSON *messages;
    cJSON *root;
    char *out;
    int collected = 0;
    double deadline;

    if (!env_nonempty("KAFKA_BOOTSTRAP_SERVERS")) {
        return coreauto_missing_env("KAFKA_BOOTSTRAP_SERVERS");
    }
    if (!topic || !topic[0]) {
        return err500("topic required");
    }
    if (max_messages < 1) {
        max_messages = 1;
    }
    if (timeout_sec <= 0) {
        timeout_sec = 30.0;
    }

    gid = (group_id && group_id[0]) ? group_id : env_nonempty("KAFKA_GROUP_ID");
    if (!gid) {
        gid = "coreauto-step";
    }
    offset_reset = env_nonempty("KAFKA_AUTO_OFFSET_RESET");
    if (!offset_reset) {
        offset_reset = "earliest";
    }

    conf = rd_kafka_conf_new();
    if (apply_common_conf(conf, errstr, sizeof(errstr)) != 0) {
        rd_kafka_conf_destroy(conf);
        return coreauto_transport_error(errstr);
    }
    if (rd_kafka_conf_set(conf, "group.id", gid, errstr, sizeof(errstr)) != RD_KAFKA_CONF_OK) {
        rd_kafka_conf_destroy(conf);
        return coreauto_transport_error(errstr);
    }
    if (rd_kafka_conf_set(conf, "auto.offset.reset", offset_reset, errstr, sizeof(errstr)) !=
        RD_KAFKA_CONF_OK) {
        rd_kafka_conf_destroy(conf);
        return coreauto_transport_error(errstr);
    }

    rk = rd_kafka_new(RD_KAFKA_CONSUMER, conf, errstr, sizeof(errstr));
    if (!rk) {
        return coreauto_transport_error(errstr);
    }

    rd_kafka_poll_set_consumer(rk);

    topics = rd_kafka_topic_partition_list_new(1);
    rd_kafka_topic_partition_list_add(topics, topic, RD_KAFKA_PARTITION_UA);
    err = rd_kafka_subscribe(rk, topics);
    rd_kafka_topic_partition_list_destroy(topics);
    if (err) {
        rd_kafka_destroy(rk);
        return coreauto_transport_error(rd_kafka_err2str(err));
    }

    messages = cJSON_CreateArray();
    deadline = timeout_sec;

    while (collected < max_messages && deadline > 0) {
        double wait = deadline < 1.0 ? deadline : 1.0;
        rd_kafka_message_t *msg =
            rd_kafka_consumer_poll(rk, (int)(wait * 1000.0));
        deadline -= wait;

        if (!msg) {
            continue;
        }
        if (msg->err) {
            if (msg->err == RD_KAFKA_RESP_ERR__PARTITION_EOF) {
                rd_kafka_message_destroy(msg);
                continue;
            }
            snprintf(errstr, sizeof(errstr), "%s", rd_kafka_message_errstr(msg));
            rd_kafka_message_destroy(msg);
            rd_kafka_destroy(rk);
            cJSON_Delete(messages);
            return err500(errstr);
        }

        {
            cJSON *entry = cJSON_CreateObject();
            cJSON *val = decode_payload(msg->payload, msg->len);
            {
                const char *tname =
                    (msg->rkt != NULL) ? rd_kafka_topic_name(msg->rkt) : topic;
                cJSON_AddStringToObject(entry, "topic", tname);
            }
            cJSON_AddNumberToObject(entry, "partition", msg->partition);
            cJSON_AddNumberToObject(entry, "offset", (double)msg->offset);
            if (val) {
                cJSON_AddItemToObject(entry, "value", val);
            }
            if (msg->key && msg->key_len > 0) {
                char *kbuf = malloc((size_t)msg->key_len + 1);
                if (kbuf) {
                    memcpy(kbuf, msg->key, (size_t)msg->key_len);
                    kbuf[msg->key_len] = '\0';
                    cJSON_AddStringToObject(entry, "key", kbuf);
                    free(kbuf);
                }
            } else {
                cJSON_AddNullToObject(entry, "key");
            }
            cJSON_AddItemToArray(messages, entry);
            collected++;
        }
        rd_kafka_message_destroy(msg);
    }

    rd_kafka_consumer_close(rk);
    rd_kafka_destroy(rk);

    root = cJSON_CreateObject();
    cJSON_AddNumberToObject(root, "status_code", 200);
    cJSON_AddItemToObject(root, "messages", messages);
    out = cJSON_PrintUnformatted(root);
    cJSON_Delete(root);
    return out;
}
