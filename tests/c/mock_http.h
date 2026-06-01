/*
 * Copyright Core DF — Apache License 2.0
 * Minimal HTTP server for C unit tests (127.0.0.1 only).
 */
#ifndef COREAUTO_MOCK_HTTP_H
#define COREAUTO_MOCK_HTTP_H

#include <stddef.h>
#include <stdint.h>

/* Starts background server; writes base URL like http://127.0.0.1:PORT into base_url (size bytes). */
int mock_http_start(char *base_url, size_t base_url_len);
void mock_http_stop(void);

#endif /* COREAUTO_MOCK_HTTP_H */
