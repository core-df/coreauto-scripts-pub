# notify — Go notification helpers for Core Auto steps

Slack, Microsoft Teams, email, and PagerDuty helpers.

## Module

`github.com/core-df/coreauto-scripts-pub/notify/Go`

## API

| Function | Description |
|----------|-------------|
| `Slack(text, webhookURL)` | Slack incoming webhook |
| `Teams(text, webhookURL)` | Teams incoming webhook |
| `Email(subject, body, toAddrs, fromAddr)` | SMTP email |
| `PagerDuty(summary, routingKey, severity)` | PagerDuty event |

## License

Apache License 2.0 — see [LICENSE](../../LICENSE).
