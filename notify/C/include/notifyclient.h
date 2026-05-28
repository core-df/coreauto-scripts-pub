/*
 * Copyright Core DF — Apache License 2.0
 */
#ifndef COREAUTO_NOTIFYCLIENT_H
#define COREAUTO_NOTIFYCLIENT_H
#ifdef __cplusplus
extern "C" {
#endif
char *notify_slack(const char *text, const char *webhook_url);
char *notify_teams(const char *text, const char *webhook_url);
char *notify_pagerduty(const char *summary, const char *routing_key, const char *severity);
char *notify_email(const char *subject, const char *body, const char *to_addrs, const char *from_addr);
#ifdef __cplusplus
}
#endif
#endif
