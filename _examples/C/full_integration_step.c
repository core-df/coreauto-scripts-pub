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
 * Core Auto real-time step — full integration example (C port).
 * Build: make
 */
#include "../../cawbs/C/include/cawbs.h"
#include "../../files/C/include/fileclient.h"
#include <cJSON.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void die(const char *msg) {
    fprintf(stderr, "%s\n", msg);
    exit(1);
}

static int json_status(const char *json) {
    cJSON *r = cJSON_Parse(json);
    if (!r) return 0;
    cJSON *sc = cJSON_GetObjectItem(r, "status_code");
    int code = sc && cJSON_IsNumber(sc) ? (int)sc->valuedouble : 0;
    cJSON_Delete(r);
    return code;
}

int main(void) {
    wbs_result r = cawbs_init();
    if (r.status_code != 200) die("cawbs_init failed");
    wbs_result_free(&r);

    r = cawbs_get_event_payload();
    if (r.status_code != 200) die("cawbs_get_event_payload failed");
    wbs_result_free(&r);

    const char *ack_dir = getenv("EXAMPLE_ACK_DIR");
    if (!ack_dir) ack_dir = "/tmp/coreauto-example";
    char path[512];
    snprintf(path, sizeof(path), "%s/unknown.json", ack_dir);

    char *wr = file_local_write(path, "{\"orderId\":\"unknown\"}");
    if (!wr || json_status(wr) != 200) die("file_local_write failed");
    free(wr);

    char out[640];
    snprintf(out, sizeof(out), "{\"orderId\":\"unknown\",\"ackPath\":\"%s\"}", path);
    r = cawbs_put_step_payload(out);
    if (r.status_code != 200) die("cawbs_put_step_payload failed");
    wbs_result_free(&r);

    printf("{\"status_code\":200,\"result\":%s}\n", out);
    return 0;
}
