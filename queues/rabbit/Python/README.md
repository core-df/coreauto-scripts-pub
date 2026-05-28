# rabbit — Python RabbitMQ helpers for Core Auto

**Publish** messages from step scripts. **Consume** is for [ingress](../ingress/Python/README.md) bridges only — not step scripts.

Part of [**queues**](../../README.md).

## Prerequisites

- Python 3
- `pip install -r requirements.txt`

## Environment variables

Either **`RABBITMQ_URL`** (`amqp://user:pass@host:5672/vhost`), or:

| Variable | Description |
|----------|-------------|
| `RABBITMQ_HOST` | Broker host (required if no URL) |
| `RABBITMQ_PORT` | Default `5672` |
| `RABBITMQ_USER` | Default `guest` |
| `RABBITMQ_PASSWORD` | Default `guest` |
| `RABBITMQ_VHOST` | Default `/` |

## Step script (publish only)

```python
import rabbitclient as rabbit

rabbit.Publish("orders", {"orderId": "123", "status": "created"})
```

## Ingress (consume → Core Auto event)

```python
import rabbitclient as rabbit
import ingress

ingress.RunBridge(rabbit.Consume, queue="orders", timeout_sec=10, max_messages=5)
```

Requires `CA_EVENT_NAME`, `ENV`, `CA_ACCESS_CODE`, `CA_WBS_URL` — see [ingress README](../ingress/Python/README.md).

## API

| Function | Use |
|----------|-----|
| `Init()` | Verify connection settings |
| `Publish(queue, value, durable=True)` | **Steps** — send to queue |
| `Consume(...)` | **Ingress only** — poll messages |

## License

Apache License 2.0 — see [LICENSE](../../../LICENSE).
