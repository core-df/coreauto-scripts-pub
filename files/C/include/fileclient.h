/*
 * Copyright Core DF — Apache License 2.0
 */
#ifndef COREAUTO_FILECLIENT_H
#define COREAUTO_FILECLIENT_H
#ifdef __cplusplus
extern "C" {
#endif
char *file_local_read(const char *path);
char *file_local_write(const char *path, const char *content);
char *file_local_move(const char *src, const char *dest);
#ifdef __cplusplus
}
#endif
#endif
