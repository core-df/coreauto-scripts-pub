# notify — Swift notification helpers for Core Auto steps

Send alerts from step scripts via Slack, Microsoft Teams, or PagerDuty. Part of **coreauto-scripts-pub**.

## Prerequisites

- macOS 12+ (Swift 5.9+)
- `swift build` in this directory

## Environment variables

| Channel | Variables |
|---------|-----------|
| Slack | `SLACK_WEBHOOK_URL` |
| Teams | `TEAMS_WEBHOOK_URL` |
| PagerDuty | `PAGERDUTY_ROUTING_KEY` |

Webhook URLs and routing keys can also be passed as function arguments.

## Usage

```swift
import Notify

Notifyclient.Slack("Batch 42 completed")
Notifyclient.Teams("Step failed: see logs")
Notifyclient.PagerDuty("Pipeline failure in step validate", severity: "error")
```

Each function returns `[String: Any]` with `status_code` (`200`, HTTP error codes, `601` for missing env, `0` for transport errors).

## API

| Function | Description |
|----------|-------------|
| `Slack(text, webhookUrl)` | Slack incoming webhook |
| `Teams(text, webhookUrl)` | Teams connector webhook |
| `PagerDuty(summary, routingKey, severity)` | PagerDuty Events API v2 |

## Email

SMTP `Email` is **not** implemented in this Swift port. Use [Python](../Python/README.md) or [Kotlin](../Kotlin/README.md) for email.

See [Python](../Python/README.md) for the full API reference.

## License

Apache License 2.0 — see [LICENSE](../../LICENSE).
