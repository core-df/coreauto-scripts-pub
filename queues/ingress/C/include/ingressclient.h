/*
 * Copyright Core DF — Apache License 2.0
 * Queue ingress bridge (C). Long-lived process: consume queue → PostEvent via cawbsingress.
 */
#ifndef COREAUTO_INGRESSCLIENT_H
#define COREAUTO_INGRESSCLIENT_H

#ifdef __cplusplus
extern "C" {
#endif

/* payload_json: JSON object string. event_name/event_source may be NULL to use env. */
char *ingress_trigger_event(const char *payload_json, const char *event_name,
                            const char *event_source);

/* consume_json: JSON {status_code, messages?, error?} from a queue consume call. */
char *ingress_forward_messages(const char *consume_json);

#ifdef __cplusplus
}
#endif

#endif
