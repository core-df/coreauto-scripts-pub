# notify — Go notification helpers for Core Auto steps

Slack, Microsoft Teams, email, and PagerDuty helpers.

## Module

`github.com/core-df/coreauto-scripts-pub/notify/Go`

## Tests

Unit tests mirror the Python suite (**21 cases**): `notifyclient`, `internal/result`, with `httptest` and a minimal SMTP test server (no real webhooks or mail relay).

```shell
cd notify/Go
go test ./... -v
```

## API

| Function | Description |
|----------|-------------|
| `Slack(text, webhookURL)` | Slack incoming webhook |
| `Teams(text, webhookURL)` | Teams incoming webhook |
| `Email(subject, body, toAddrs, fromAddr)` | SMTP email |
| `PagerDuty(summary, routingKey, severity)` | PagerDuty event |

## License

Apache License 2.0 — see [LICENSE](../../LICENSE).
