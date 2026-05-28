#include "../../C/include/transformclient.h"
#include "../../http/C/include/coreauto_result.h"
#include <string.h>
void TRANSJSONPARSE(int *status, char *out_buf, char *err_buf, char *in_buf) {
    char *json = transform_json_parse(in_buf);
    if (!json) { *status=400; return; }
    strncpy(out_buf, json, 8191); coreauto_json_free(json); *status=200;
}
void TRANSJSONSTRINGIFY(int *status, char *out_buf, char *err_buf, char *in_buf) {
    char *json = transform_json_stringify(in_buf);
    if (!json) { *status=400; return; }
    strncpy(out_buf, json, 8191); coreauto_json_free(json); *status=200;
}
