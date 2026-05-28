# notify — Python notification helpers for Core Auto steps

Send alerts from step scripts via Slack, Teams, SMTP email, or PagerDuty.

## Prerequisites

- Python 3
- `pip install -r requirements.txt` (email uses stdlib `smtplib`)

## Environment variables

| Channel | Variables |
|---------|-----------|
| Slack | `SLACK_WEBHOOK_URL` |
| Teams | `TEAMS_WEBHOOK_URL` |
| Email | `SMTP_HOST`, `SMTP_PORT` (default 587), `SMTP_USER`, `SMTP_PASSWORD`, `SMTP_FROM` |
| PagerDuty | `PAGERDUTY_ROUTING_KEY` |

## Usage

```python
import notifyclient as notify

notify.Slack("Batch 42 completed")
notify.Teams("Step failed: see logs")
notify.Email("Core Auto alert", "Details...", "ops@example.com")
notify.PagerDuty("Pipeline failure in step validate")
```

## API

| Function | Description |
|----------|-------------|
| `Slack(text, webhook_url=None)` | Incoming webhook |
| `Teams(text, webhook_url=None)` | Connector webhook |
| `Email(subject, body, to_addrs, from_addr=None)` | SMTP |
| `PagerDuty(summary, routing_key=None, severity="error")` | Events API v2 |

## License

Apache License 2.0 — see [LICENSE](../../LICENSE).
