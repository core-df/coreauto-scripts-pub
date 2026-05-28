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
 */

#include "cawbsingress.h"

#include <stdlib.h>

static wbs_session *g_sess;

static const char *env_or_empty(const char *name)
{
    const char *v = getenv(name);
    return v ? v : "";
}

wbs_result cawbsingress_init(void)
{
    if (!g_sess) {
        g_sess = wbs_session_new();
    }
    if (!*env_or_empty("ENV") || !*env_or_empty("CA_ACCESS_CODE") ||
        !*env_or_empty("CA_WBS_URL")) {
        return wbs_missing_env("ENV, CA_ACCESS_CODE, CA_WBS_URL");
    }
    return wbs_authenticate(g_sess, env_or_empty("ENV"), env_or_empty("CA_ACCESS_CODE"),
                            env_or_empty("CA_WBS_URL"));
}

wbs_result cawbsingress_post_event(const char *event_name, const char *payload_json,
                                   const char *event_source)
{
    return wbs_post_event(g_sess, event_name, payload_json, event_source);
}

wbs_result cawbsingress_get_event_status(const char *action_id)
{
    return wbs_get_event_status(g_sess, action_id);
}

wbs_result cawbsingress_get_event_list(void)
{
    return wbs_get_event_list(g_sess);
}

wbs_result cawbsingress_submit_flag(const char *name, const char *system_name,
                                      const char *source_system_name, const char *date)
{
    return wbs_submit_flag(g_sess, name, system_name, source_system_name, date);
}

wbs_result cawbsingress_get_keystore(const char *keylist)
{
    return wbs_get_keystore(g_sess, keylist);
}
