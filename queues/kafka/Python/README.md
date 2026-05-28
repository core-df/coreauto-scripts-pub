# kafka — Python Kafka helpers for Core Auto

**Produce** messages from step scripts. **Consume** is for [ingress](../ingress/Python/README.md) bridges only — not step scripts.

Part of [**queues**](../../README.md).

## Prerequisites

- Python 3
- `pip install -r requirements.txt`

## Environment variables

| Variable | Description |
|----------|-------------|
| `KAFKA_BOOTSTRAP_SERVERS` | Broker list (required) |
| `KAFKA_GROUP_ID` | Consumer group for ingress (default: `coreauto-step`) |
| `KAFKA_SECURITY_PROTOCOL` | Optional (e.g. `SASL_SSL`) |
| `KAFKA_SASL_MECHANISM` | Optional |
| `KAFKA_SASL_USERNAME` / `KAFKA_SASL_PASSWORD` | Optional SASL credentials |
| `KAFKA_AUTO_OFFSET_RESET` | Default `earliest` |

## Step script (produce only)

```python
import kafkaclient as kafka

kafka.Produce("orders", {"orderId": "123", "status": "created"})
```

## Ingress (consume → Core Auto event)

```python
import kafkaclient as kafka
import ingress

ingress.RunBridge(kafka.Consume, topic="orders", timeout_sec=30, max_messages=10)
```

Requires `CA_EVENT_NAME`, `ENV`, `CA_ACCESS_CODE`, `CA_WBS_URL` — see [ingress README](../ingress/Python/README.md).

## API

| Function | Use |
|----------|-----|
| `Init()` | Verify `KAFKA_BOOTSTRAP_SERVERS` |
| `Produce(topic, value, key=None)` | **Steps** — publish message |
| `Consume(...)` | **Ingress only** — poll messages |

## License

Apache License 2.0 — see [LICENSE](../../../LICENSE).
