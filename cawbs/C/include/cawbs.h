/*
 * Copyright (c) Core DF. All rights reserved.
 *
 * Core Auto Web Services library (cawbs) — real-time C client.
 *
 * Documentation: https://coreauto.coredf.com/resources
 */

#ifndef CAWBS_CAWBS_H
#define CAWBS_CAWBS_H

#include "wbs.h"

#ifdef __cplusplus
extern "C" {
#endif

wbs_result cawbs_init(void);
wbs_result cawbs_get_event_payload(void);
wbs_result cawbs_put_step_payload(const char *payload_json);
wbs_result cawbs_get_step_payload(const char *stepname);
wbs_result cawbs_get_keystore(const char *keylist);

#ifdef __cplusplus
}
#endif

#endif /* CAWBS_CAWBS_H */
