# notify — COBOL

GnuCOBOL bridge to the [C notify client](../C/README.md).

## Build

```shell
cd notify/COBOL
make
```

## Entry points

| Entry | Description |
|-------|-------------|
| `NOTIFYSLACK` | Slack webhook |
| `NOTIFYTEAMS` | Microsoft Teams webhook |
| `NOTIFYPAGERDUTY` | PagerDuty Events v2 |
| `NOTIFYEMAIL` | SMTP email |

Apache License 2.0.
