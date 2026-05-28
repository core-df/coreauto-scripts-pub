# notify — Lua notification helpers for Core Auto steps

Send alerts via Slack, Microsoft Teams, or PagerDuty. Part of **coreauto-scripts-pub**.

## Prerequisites

- Lua 5.x
- `curl` on `PATH`

Add this directory’s `lib/` folder to `LUA_PATH`.

## Environment variables

| Channel | Variables |
|---------|-----------|
| Slack | `SLACK_WEBHOOK_URL` |
| Teams | `TEAMS_WEBHOOK_URL` |
| PagerDuty | `PAGERDUTY_ROUTING_KEY` |

## Usage

```lua
local notify = require("notifyclient")

notify.Slack("Batch 42 completed")
notify.Teams("Step failed: see logs")
notify.PagerDuty("Pipeline failure", nil, "error")
```

## API

| Function | Description |
|----------|-------------|
| `Slack(text, webhook_url)` | Slack incoming webhook |
| `Teams(text, webhook_url)` | Teams connector webhook |
| `PagerDuty(summary, routing_key, severity)` | PagerDuty Events API v2 |

## Email

SMTP `Email` is **not** implemented in this Lua port. Use [Python](../Python/README.md).

See [Python](../Python/README.md) for the full API reference.

## License

Apache License 2.0 — see [LICENSE](../../LICENSE).
