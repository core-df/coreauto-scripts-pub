# servicebus — Python Azure Service Bus helpers for Core Auto

**Send** messages from step scripts. **Receive** is for [ingress](../ingress/Python/README.md) bridges only — not step scripts.

Part of [**queues**](../../README.md).

## Prerequisites

- Python 3
- `pip install -r requirements.txt`

## Environment variables

| Variable | Description |
|----------|-------------|
| `SERVICE_BUS_CONNECTION_STRING` | Namespace connection string (required) |
| `SERVICE_BUS_QUEUE_NAME` | Default queue name |

## Step script (send only)

```python
import servicebusclient as servicebus

servicebus.Send({"orderId": "123", "status": "created"})
```

## Ingress (receive → Core Auto event)

```python
import servicebusclient as servicebus
import ingress

ingress.RunBridge(servicebus.Receive, timeout_sec=30, max_messages=5)
```

Requires `CA_EVENT_NAME`, `ENV`, `CA_ACCESS_CODE`, `CA_WBS_URL` — see [ingress README](../ingress/Python/README.md).

## API

| Function | Use |
|----------|-----|
| `Init()` | Verify connection string and default queue |
| `Send(value, queue=None)` | **Steps** — publish to queue |
| `Receive(...)` | **Ingress only** — receive messages |

## License

Apache License 2.0 — see [LICENSE](../../../LICENSE).
