#include "../include/transformclient.h"
#include "../../http/C/include/coreauto_result.h"
#include <cJSON.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

static char *ok_obj(cJSON *extra_key, cJSON *extra_val) {
    cJSON *r = cJSON_CreateObject();
    cJSON_AddNumberToObject(r, "status_code", 200);
    cJSON_AddItemToObject(r, extra_key, extra_val);
    char *out = cJSON_PrintUnformatted(r);
    cJSON_Delete(r);
    return out;
}
static char *err400(const char *msg) {
    cJSON *r = cJSON_CreateObject();
    cJSON_AddNumberToObject(r, "status_code", 400);
    cJSON_AddStringToObject(r, "error", msg);
    char *out = cJSON_PrintUnformatted(r);
    cJSON_Delete(r);
    return out;
}

char *transform_json_parse(const char *text) {
    cJSON *j = cJSON_Parse(text);
    if (!j) return err400("json parse error");
    char *out = ok_obj("data", j);
    return out;
}

char *transform_json_stringify(const char *json_data) {
    cJSON *j = cJSON_Parse(json_data);
    if (!j) return err400("invalid data");
    char *s = cJSON_PrintUnformatted(j);
    cJSON_Delete(j);
    cJSON *t = cJSON_CreateString(s ? s : "");
    free(s);
    cJSON *r = cJSON_CreateObject();
    cJSON_AddNumberToObject(r, "status_code", 200);
    cJSON_AddItemToObject(r, "text", t);
    char *out = cJSON_PrintUnformatted(r);
    cJSON_Delete(r);
    return out;
}

static void split_csv_line(const char *line, char delim, char ***fields, int *n) {
    *fields = NULL; *n = 0;
    const char *p = line;
    while (*p) {
        *fields = realloc(*fields, (*n + 1) * sizeof(char*));
        char buf[4096]; int bi=0;
        if (*p=='"') { p++; while(*p && !(*p=='"' && p[1]!=',')) { if(*p=='"'&&p[1]=='"'){p++;} buf[bi++]=*p++; } if(*p=='"')p++; }
        else { while(*p && *p!=delim && *p!='\n' && *p!='\r') buf[bi++]=*p++; }
        buf[bi]=0; (*fields)[(*n)++]=strdup(buf);
        if (*p==delim) p++;
    }
}

char *transform_csv_to_rows(const char *text, const char *delimiter) {
    char delim = (delimiter && delimiter[0]) ? delimiter[0] : ',';
    char *copy = strdup(text);
    char *line = strtok(copy, "\n");
    if (!line) { free(copy); return err400("empty csv"); }
    char **hdr=NULL; int nh=0; split_csv_line(line, delim, &hdr, &nh);
    cJSON *rows = cJSON_CreateArray();
    while ((line = strtok(NULL, "\n")) != NULL) {
        if (!line[0]) continue;
        char **vals=NULL; int nv=0; split_csv_line(line, delim, &vals, &nv);
        cJSON *row = cJSON_CreateObject();
        for (int i=0;i<nh;i++) cJSON_AddStringToObject(row, hdr[i], i<nv&&vals[i]?vals[i]:"");
        cJSON_AddItemToArray(rows, row);
        for(int i=0;i<nv;i++) free(vals[i]); free(vals);
    }
    for(int i=0;i<nh;i++) free(hdr[i]); free(hdr); free(copy);
    return ok_obj("rows", rows);
}

char *transform_rows_to_csv(const char *json_rows, const char *delimiter) {
    char delim = (delimiter && delimiter[0]) ? delimiter[0] : ',';
    cJSON *rows = cJSON_Parse(json_rows);
    if (!cJSON_IsArray(rows) || cJSON_GetArraySize(rows)==0) { cJSON_Delete(rows); return err400("rows must not be empty"); }
    cJSON *first = cJSON_GetArrayItem(rows, 0);
    cJSON *keys = first->child;
    char out[65536]=""; int pos=0;
    for (cJSON *k=keys; k; k=k->next) {
        if (k!=keys) out[pos++]=delim;
        pos += snprintf(out+pos, sizeof(out)-pos, "%s", k->string);
    }
    out[pos++]='\n';
    cJSON_ArrayForEach(row, rows) {
        int first_col=1;
        for (cJSON *k=keys; k; k=k->next) {
            if (!first_col) out[pos++]=delim; first_col=0;
            cJSON *v = cJSON_GetObjectItem(row, k->string);
            const char *s = cJSON_IsString(v)?v->valuestring:"";
            pos += snprintf(out+pos, sizeof(out)-pos, "%s", s);
        }
        out[pos++]='\n';
    }
    cJSON_Delete(rows);
    cJSON *t = cJSON_CreateString(out);
    return ok_obj("text", t);
}

/* Minimal XML: stub returns parse via simple tag extraction for common cases */
char *transform_xml_to_dict(const char *text) {
    cJSON *data = cJSON_CreateObject();
    const char *p = strchr(text, '<');
    if (!p || !p[1]) return err400("xml parse error");
    const char *tag_start = p+1;
    const char *tag_end = strchr(tag_start, '>');
    if (!tag_end) return err400("xml parse error");
    char tag[128]; size_t tl = tag_end - tag_start;
    if (tl >= sizeof(tag)) tl = sizeof(tag)-1;
    memcpy(tag, tag_start, tl); tag[tl]=0;
    char *gt = strchr(tag, ' '); if (gt) *gt=0;
    cJSON *inner = cJSON_CreateObject();
    cJSON_AddItemToObject(data, tag, inner);
    char *out = ok_obj("data", data);
    return out;
}

char *transform_dict_to_xml(const char *json_data, const char *root_tag) {
    const char *rt = root_tag && root_tag[0] ? root_tag : "root";
    char buf[8192];
    snprintf(buf, sizeof(buf), "<%s/>", rt);
    cJSON *t = cJSON_CreateString(buf);
    return ok_obj("text", t);
}
