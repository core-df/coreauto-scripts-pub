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
 * COBOL-callable bridge for the Core Auto cawbs C client (GnuCOBOL).
 */

#include "../../C/include/cawbs.h"
#include "../../C/include/cawbsbatch.h"
#include "../../C/include/cawbsingress.h"
#include "../../C/include/wbs.h"

#include <string.h>

static void copy_str(char *dest, int dest_len, const char *src)
{
    if (!dest || dest_len <= 0) {
        return;
    }
    if (!src) {
        dest[0] = '\0';
        return;
    }
    strncpy(dest, src, (size_t)dest_len - 1);
    dest[dest_len - 1] = '\0';
}

static void copy_error(char *dest, int dest_len, wbs_result r)
{
    if (r.error) {
        copy_str(dest, dest_len, r.error);
    } else {
        dest[0] = '\0';
    }
}

static void copy_payload(char *dest, int dest_len, wbs_result r)
{
    if (r.payload) {
        copy_str(dest, dest_len, r.payload);
    } else {
        dest[0] = '\0';
    }
}

static void copy_answer(char *dest, int dest_len, wbs_result r)
{
    if (r.answer) {
        copy_str(dest, dest_len, r.answer);
    } else {
        dest[0] = '\0';
    }
}

void CAWBSRTINIT(int *status_code, char *error_buf)
{
    wbs_result r = cawbs_init();
    *status_code = r.status_code;
    copy_error(error_buf, 512, r);
    wbs_result_free(&r);
}

void CAWBSRTGETEVENT(int *status_code, char *payload_buf, char *error_buf)
{
    wbs_result r = cawbs_get_event_payload();
    *status_code = r.status_code;
    copy_error(error_buf, 512, r);
    copy_payload(payload_buf, 8192, r);
    wbs_result_free(&r);
}

void CAWBSRTPUTSTEP(int *status_code, char *payload_json, char *error_buf)
{
    wbs_result r = cawbs_put_step_payload(payload_json);
    *status_code = r.status_code;
    copy_error(error_buf, 512, r);
    wbs_result_free(&r);
}

void CAWBSRTGETSTEP(int *status_code, char *stepname, char *payload_buf, char *error_buf)
{
    wbs_result r = cawbs_get_step_payload(stepname);
    *status_code = r.status_code;
    copy_error(error_buf, 512, r);
    copy_payload(payload_buf, 8192, r);
    wbs_result_free(&r);
}

void CAWBSRTGETKS(int *status_code, char *keylist, char *answer_buf, char *error_buf)
{
    wbs_result r = cawbs_get_keystore(keylist);
    *status_code = r.status_code;
    copy_error(error_buf, 512, r);
    copy_answer(answer_buf, 8192, r);
    wbs_result_free(&r);
}

void CAWBSBATCHINIT(int *status_code, char *error_buf)
{
    wbs_result r = cawbsbatch_init();
    *status_code = r.status_code;
    copy_error(error_buf, 512, r);
    wbs_result_free(&r);
}

void CAWBSBATCHGETKS(int *status_code, char *keylist, char *answer_buf, char *error_buf)
{
    wbs_result r = cawbsbatch_get_keystore(keylist);
    *status_code = r.status_code;
    copy_error(error_buf, 512, r);
    copy_answer(answer_buf, 8192, r);
    wbs_result_free(&r);
}

void CAWBSINGRESSINIT(int *status_code, char *error_buf)
{
    wbs_result r = cawbsingress_init();
    *status_code = r.status_code;
    copy_error(error_buf, 512, r);
    wbs_result_free(&r);
}

void CAWBSINGRESSPOSTEVENT(int *status_code, char *answer_buf, char *error_buf,
                           char *event_name, char *payload_json, char *event_source)
{
    wbs_result r = cawbsingress_post_event(event_name, payload_json,
                                           event_source && event_source[0] ? event_source : NULL);
    *status_code = r.status_code;
    copy_error(error_buf, 512, r);
    copy_answer(answer_buf, 8192, r);
    wbs_result_free(&r);
}

void CAWBSINGRESSGETSTATUS(int *status_code, char *answer_buf, char *error_buf, char *action_id)
{
    wbs_result r = cawbsingress_get_event_status(action_id);
    *status_code = r.status_code;
    copy_error(error_buf, 512, r);
    copy_answer(answer_buf, 8192, r);
    wbs_result_free(&r);
}

void CAWBSINGRESSGETLIST(int *status_code, char *answer_buf, char *error_buf)
{
    wbs_result r = cawbsingress_get_event_list();
    *status_code = r.status_code;
    copy_error(error_buf, 512, r);
    copy_answer(answer_buf, 8192, r);
    wbs_result_free(&r);
}

void CAWBSINGRESSSUBMITFLAG(int *status_code, char *answer_buf, char *error_buf,
                            char *name, char *system_name, char *source_system_name, char *date)
{
    wbs_result r = cawbsingress_submit_flag(name, system_name, source_system_name, date);
    *status_code = r.status_code;
    copy_error(error_buf, 512, r);
    copy_answer(answer_buf, 8192, r);
    wbs_result_free(&r);
}

void CAWBSINGRESSGETKS(int *status_code, char *keylist, char *answer_buf, char *error_buf)
{
    wbs_result r = cawbsingress_get_keystore(keylist);
    *status_code = r.status_code;
    copy_error(error_buf, 512, r);
    copy_answer(answer_buf, 8192, r);
    wbs_result_free(&r);
}
