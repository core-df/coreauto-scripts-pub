/*
 * Copyright Core DF
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
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
