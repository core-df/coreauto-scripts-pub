# nats — Python NATS helpers for Core Auto

**Publish** messages from step scripts. **Subscribe** is for [ingress](../ingress/Python/README.md) bridges only — not step scripts.

Part of [**queues**](../../README.md).

## Prerequisites

- Python 3
- `pip install -r requirements.txt`

## Environment variables

| Variable | Description |
|----------|-------------|
| `NATS_URL` | Server URL (e.g. `nats://localhost:4222`) |
| `NATS_SERVERS` | Alias for `NATS_URL` |

## Step script (publish only)

```python
import natsclient as nats

nats.Publish("orders.created", {"orderId": "123"})
```

## Ingress (subscribe → Core Auto event)

```python
import natsclient as nats
import ingress

ingress.RunBridge(nats.Subscribe, subject="orders.created", timeout_sec=10, max_messages=5)
```

Requires `CA_EVENT_NAME`, `ENV`, `CA_ACCESS_CODE`, `CA_WBS_URL` — see [ingress README](../ingress/Python/README.md).

## API

| Function | Use |
|----------|-----|
| `Init()` | Verify `NATS_URL` / `NATS_SERVERS` |
| `Publish(subject, value)` | **Steps** — fire-and-forget publish |
| `Subscribe(...)` | **Ingress only** — poll messages on subject |

## License

Apache License 2.0 — see [LICENSE](../../../LICENSE).
