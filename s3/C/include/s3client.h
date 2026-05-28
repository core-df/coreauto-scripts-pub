/*
 * Copyright Core DF — Apache License 2.0
 */
#ifndef COREAUTO_S3CLIENT_H
#define COREAUTO_S3CLIENT_H
#ifdef __cplusplus
extern "C" {
#endif
char *s3_init(void);
char *s3_get_object(const char *key, const char *bucket);
char *s3_put_object(const char *key, const char *content, const char *bucket);
char *s3_list_objects(const char *prefix, const char *bucket);
#ifdef __cplusplus
}
#endif
#endif
