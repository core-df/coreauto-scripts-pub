# sqs — Python Amazon SQS helpers for Core Auto

**Send** messages from step scripts. **Receive** is for [ingress](../ingress/Python/README.md) bridges only — not step scripts.

Part of [**queues**](../../README.md).

## Prerequisites

- Python 3
- `pip install -r requirements.txt`

## Environment variables

| Variable | Description |
|----------|-------------|
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | Credentials (or `AWS_PROFILE`) |
| `AWS_REGION` | Region (default `us-east-1`) |
| `SQS_QUEUE_URL` | Default queue URL |
| `SQS_ENDPOINT_URL` | Optional custom endpoint (LocalStack, etc.) |

## Step script (send only)

```python
import sqsclient as sqs

sqs.Send({"orderId": "123", "status": "created"})
```

## Ingress (receive → Core Auto event)

```python
import sqsclient as sqs
import ingress

ingress.RunBridge(sqs.Receive, max_messages=5, wait_time_sec=20)
```

Requires `CA_EVENT_NAME`, `ENV`, `CA_ACCESS_CODE`, `CA_WBS_URL` — see [ingress README](../ingress/Python/README.md).

## API

| Function | Use |
|----------|-----|
| `Init()` | Verify credentials and default queue URL |
| `Send(value, queue_url=None)` | **Steps** — publish message |
| `Receive(...)` | **Ingress only** — long-poll messages |

## License

Apache License 2.0 — see [LICENSE](../../../LICENSE).
