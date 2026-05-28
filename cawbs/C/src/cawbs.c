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

#include "cawbs.h"

#include <stdlib.h>

static wbs_session *g_sess;

static const char *env_or_empty(const char *name)
{
    const char *v = getenv(name);
    return v ? v : "";
}

wbs_result cawbs_init(void)
{
    if (!g_sess) {
        g_sess = wbs_session_new();
    }
    if (!*env_or_empty("ENV") || !*env_or_empty("ACTIONID") ||
        !*env_or_empty("CA_ACCESS_CODE") || !*env_or_empty("CA_WBS_URL") ||
        !*env_or_empty("STEPNAME")) {
        return wbs_missing_env("ENV, ACTIONID, CA_ACCESS_CODE, CA_WBS_URL, STEPNAME");
    }
    return wbs_authenticate(g_sess, env_or_empty("ENV"), env_or_empty("CA_ACCESS_CODE"),
                            env_or_empty("CA_WBS_URL"));
}

wbs_result cawbs_get_event_payload(void)
{
    return wbs_get_event_payload(g_sess, env_or_empty("ACTIONID"));
}

wbs_result cawbs_put_step_payload(const char *payload_json)
{
    return wbs_put_step_payload(g_sess, env_or_empty("ACTIONID"), env_or_empty("STEPNAME"),
                                payload_json);
}

wbs_result cawbs_get_step_payload(const char *stepname)
{
    return wbs_get_step_payload(g_sess, env_or_empty("ACTIONID"), stepname);
}

wbs_result cawbs_get_keystore(const char *keylist)
{
    return wbs_get_keystore(g_sess, keylist);
}
