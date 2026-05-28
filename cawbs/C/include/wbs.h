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
 * Core Auto Web Services library (cawbs) — shared C client types.
 */

#ifndef CAWBS_WBS_H
#define CAWBS_WBS_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct wbs_result {
    int status_code;
    char *error;
    char *payload;
    char *answer;
} wbs_result;

typedef struct wbs_session wbs_session;

void wbs_result_free(wbs_result *result);

wbs_session *wbs_session_new(void);
void wbs_session_free(wbs_session *session);

wbs_result wbs_missing_env(const char *vars);
wbs_result wbs_authenticate(wbs_session *session, const char *env,
                            const char *access_code, const char *base_url);
wbs_result wbs_get_event_payload(wbs_session *session, const char *action_id);
wbs_result wbs_put_step_payload(wbs_session *session, const char *action_id,
                                const char *step_name, const char *payload_json);
wbs_result wbs_get_step_payload(wbs_session *session, const char *action_id,
                                const char *step_name);
wbs_result wbs_get_keystore(wbs_session *session, const char *keylist);

#ifdef __cplusplus
}
#endif

#endif /* CAWBS_WBS_H */
