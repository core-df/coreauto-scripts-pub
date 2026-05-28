# ibmmq — Python IBM MQ helpers for Core Auto

**Put** messages from step scripts. **Get** is for [ingress](../ingress/Python/README.md) bridges only — not step scripts.

Part of [**queues**](../../README.md).

## Prerequisites

- Python 3
- `pip install -r requirements.txt`
- **IBM MQ client libraries** on the worker (required by `pymqi`)

## Environment variables

| Variable | Description |
|----------|-------------|
| `MQ_HOST` | Queue manager host |
| `MQ_PORT` | Port (default `1414`) |
| `MQ_QUEUE_MANAGER` | Queue manager name |
| `MQ_CHANNEL` | SVRCONN channel (default `SYSTEM.DEF.SVRCONN`) |
| `MQ_QUEUE` | Default queue name |
| `MQ_USER` / `MQ_PASSWORD` | Optional credentials |

## Step script (put only)

```python
import ibmmqclient as ibmmq

ibmmq.Put({"orderId": "123", "status": "created"})
```

## Ingress (get → Core Auto event)

```python
import ibmmqclient as ibmmq
import ingress

ingress.RunBridge(ibmmq.Get, timeout_sec=30, max_messages=5)
```

Requires `CA_EVENT_NAME`, `ENV`, `CA_ACCESS_CODE`, `CA_WBS_URL` — see [ingress README](../ingress/Python/README.md).

## API

| Function | Use |
|----------|-----|
| `Init()` | Verify MQ settings and default queue |
| `Put(value, queue=None)` | **Steps** — put message |
| `Get(...)` | **Ingress only** — get messages (wait) |

## License

Apache License 2.0 — see [LICENSE](../../../LICENSE).
