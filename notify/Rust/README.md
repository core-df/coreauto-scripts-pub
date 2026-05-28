# notify — Rust notification helpers for Core Auto steps

Send alerts from step scripts via Slack, Microsoft Teams, or PagerDuty. Part of **coreauto-scripts-pub**.

## Prerequisites

- Rust 1.70+
- `cargo build` (ureq, serde_json)

## Environment variables

| Channel | Variables |
|---------|-----------|
| Slack | `SLACK_WEBHOOK_URL` |
| Teams | `TEAMS_WEBHOOK_URL` |
| PagerDuty | `PAGERDUTY_ROUTING_KEY` |

Webhook URLs and routing keys can also be passed as function arguments.

## Usage

```rust
use coreauto_notify::{slack, teams, pagerduty};

let r = slack("Batch 42 completed", None);
let r = teams("Step failed: see logs", None);
let r = pagerduty("Pipeline failure in step validate", None, Some("error"));
```

Each function returns `serde_json::Value` with `status_code` (`200`, HTTP error codes, `601` for missing env, `0` for transport errors).

## API

| Function | Description |
|----------|-------------|
| `slack(text, webhook_url)` | Slack incoming webhook |
| `teams(text, webhook_url)` | Teams connector webhook |
| `pagerduty(summary, routing_key, severity)` | PagerDuty Events API v2 |

## Email

SMTP `Email` is **not** implemented here. Use [Python](../Python/README.md) (stdlib `smtplib`) or add `lettre` in your step crate if you need Rust-native email.

## License

Apache License 2.0 — see [LICENSE](../../LICENSE).
