# ingress — queue → Core Auto event bridge

Long-running **ingress processes** read from a message queue and call **`cawbsingress.PostEvent`** so Core Auto starts a real-time workflow. This is **not** for step scripts — steps run once and exit; they cannot poll a queue.

## Architecture

```
Queue (Kafka, RabbitMQ, SQS, …)
        ↓  ingress process (this module + queue client)
Collector POST /v1/rtevent
        ↓
Core Auto real-time workflow
        ↓
Step script: cawbs.GetEventPayload() → process → cawbs.PutStepPayload()
```

## Prerequisites

- Python 3
- `pip install -r requirements.txt`
- [`cawbsingress`](../../../cawbs/Python/cawbsingress.py) on `PYTHONPATH` (or set `CAWBS_PYTHON`)
- Queue client on `PYTHONPATH`, e.g. `queues/kafka/Python`

```shell
export PYTHONPATH="/path/to/coreauto-scripts-pub/cawbs/Python:/path/to/coreauto-scripts-pub/queues/kafka/Python:/path/to/coreauto-scripts-pub/queues/ingress/Python:${PYTHONPATH}"
```

## Environment variables

| Variable | Description |
|----------|-------------|
| `ENV` | Core Auto environment |
| `CA_ACCESS_CODE` | Collector API code |
| `CA_WBS_URL` | Collector base URL |
| `CA_EVENT_NAME` | Event definition name (must exist in Core Auto) |
| `CA_EVENT_SOURCE` | Optional `eventSource` field |
| `CAWBS_PYTHON` | Optional path to `cawbs/Python` |

Plus the env vars for your queue backend (see that backend's README).

## Usage

Kafka example — run in a loop as a systemd service or container:

```python
import kafkaclient as kafka
import ingress

while True:
    result = ingress.RunBridge(
        kafka.Consume,
        topic="orders",
        timeout_sec=30,
        max_messages=10,
    )
    if result.get("status_code", 0) >= 400:
        raise RuntimeError(result)
```

Or forward a payload you already have:

```python
import ingress

ingress.TriggerEvent({"orderId": "123"})
```

## API

| Function | Description |
|----------|-------------|
| `TriggerEvent(payload, event_name=None, event_source=None)` | POST /v1/rtevent via cawbsingress |
| `ForwardMessages(consume_result)` | Map queue messages → events |
| `RunBridge(consume_fn, **kwargs)` | Consume once + forward |

## License

Apache License 2.0 — see [LICENSE](../../../LICENSE).
