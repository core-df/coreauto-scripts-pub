/*
 * Copyright Core DF — Apache License 2.0
 * Kafka helpers for Core Auto (C) — requires librdkafka at link time.
 */
#ifndef COREAUTO_KAFKACLIENT_H
#define COREAUTO_KAFKACLIENT_H

#ifdef __cplusplus
extern "C" {
#endif

/* Returns malloc'd JSON {status_code, error?}. Caller frees with free(). */
char *kafka_init(void);

/* value: UTF-8 text or JSON (objects/arrays are serialized). key may be NULL. */
char *kafka_produce(const char *topic, const char *value, const char *key);

/* Ingress bridges only. group_id may be NULL (uses KAFKA_GROUP_ID or coreauto-step). */
char *kafka_consume(const char *topic, double timeout_sec, int max_messages,
                    const char *group_id);

#ifdef __cplusplus
}
#endif

#endif
