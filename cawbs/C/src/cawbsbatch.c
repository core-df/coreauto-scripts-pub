/*
 * Copyright (c) Core DF. All rights reserved.
 */

#include "cawbsbatch.h"

#include <stdlib.h>

static wbs_session *g_sess;

static const char *env_or_empty(const char *name)
{
    const char *v = getenv(name);
    return v ? v : "";
}

wbs_result cawbsbatch_init(void)
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

wbs_result cawbsbatch_get_keystore(const char *keylist)
{
    return wbs_get_keystore(g_sess, keylist);
}
