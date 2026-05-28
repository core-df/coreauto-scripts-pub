# notify — Dart notification helpers for Core Auto steps

Send alerts from step scripts via Slack, Microsoft Teams, or PagerDuty. Part of **coreauto-scripts-pub**.

## Prerequisites

- Dart SDK 3.0+
- `dart pub get` (package:http)

## Environment variables

| Channel | Variables |
|---------|-----------|
| Slack | `SLACK_WEBHOOK_URL` |
| Teams | `TEAMS_WEBHOOK_URL` |
| PagerDuty | `PAGERDUTY_ROUTING_KEY` |

## Usage

```dart
import 'package:coreauto_notify/notifyclient.dart';

await Notifyclient.Slack('Batch 42 completed');
await Notifyclient.Teams('Step failed: see logs');
await Notifyclient.PagerDuty('Pipeline failure', severity: 'error');
```

Each function returns `Future<Map<String, dynamic>>` with `status_code` (`200`, HTTP error codes, `601`, `0`).

## API

| Function | Description |
|----------|-------------|
| `Slack(text, {webhookUrl})` | Slack incoming webhook |
| `Teams(text, {webhookUrl})` | Teams connector webhook |
| `PagerDuty(summary, {routingKey, severity})` | PagerDuty Events API v2 |

## Email

SMTP `Email` is **not** implemented in this Dart port. Use [Python](../Python/README.md) or [Kotlin](../Kotlin/README.md).

See [Python](../Python/README.md) for the full API reference.

## License

Apache License 2.0 — see [LICENSE](../../LICENSE).
