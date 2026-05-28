/*
 * Copyright (c) Core DF. All rights reserved.
 *
 * COBOL-callable bridge for the Core Auto cawbs C client (GnuCOBOL).
 */

#include "../../C/include/cawbs.h"
#include "../../C/include/cawbsbatch.h"
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
