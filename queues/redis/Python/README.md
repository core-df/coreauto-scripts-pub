# redis — Python Redis queue helpers for Core Auto

**Push** messages from step scripts. **Pop** is for [ingress](../ingress/Python/README.md) bridges only — not step scripts.

Part of [**queues**](../../README.md).

## Prerequisites

- Python 3
- `pip install -r requirements.txt`

## Environment variables

Either **`REDIS_URL`** (`redis://:password@host:6379/0`), or:

| Variable | Description |
|----------|-------------|
| `REDIS_HOST` | Server host (required if no URL) |
| `REDIS_PORT` | Default `6379` |
| `REDIS_PASSWORD` | Optional |
| `REDIS_DB` | Database index (default `0`) |

## Step script (push only)

```python
import redisclient as redis

redis.Push("orders", {"orderId": "123", "status": "created"})
```

## Ingress (pop → Core Auto event)

```python
import redisclient as redis
import ingress

ingress.RunBridge(redis.Pop, queue="orders", timeout_sec=10, max_messages=5)
```

Requires `CA_EVENT_NAME`, `ENV`, `CA_ACCESS_CODE`, `CA_WBS_URL` — see [ingress README](../ingress/Python/README.md).

## API

| Function | Use |
|----------|-----|
| `Init()` | Verify connection settings |
| `Push(queue, value)` | **Steps** — enqueue (left push) |
| `Pop(...)` | **Ingress only** — blocking dequeue |

## License

Apache License 2.0 — see [LICENSE](../../../LICENSE).
