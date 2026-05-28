#ifndef COREAUTO_TRANSFORM_H
#define COREAUTO_TRANSFORM_H
#ifdef __cplusplus
extern "C" {
#endif
char *transform_json_parse(const char *text);
char *transform_json_stringify(const char *json_data);
char *transform_csv_to_rows(const char *text, const char *delimiter);
char *transform_rows_to_csv(const char *json_rows, const char *delimiter);
char *transform_xml_to_dict(const char *text);
char *transform_dict_to_xml(const char *json_data, const char *root_tag);
#ifdef __cplusplus
}
#endif
#endif
