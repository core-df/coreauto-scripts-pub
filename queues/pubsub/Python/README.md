# pubsub — Python Google Cloud Pub/Sub helpers for Core Auto

**Publish** messages from step scripts. **Pull** is for [ingress](../ingress/Python/README.md) bridges only — not step scripts.

Part of [**queues**](../../README.md).

## Prerequisites

- Python 3
- `pip install -r requirements.txt`
- GCP credentials via **`GOOGLE_APPLICATION_CREDENTIALS`** or Application Default Credentials

## Environment variables

| Variable | Description |
|----------|-------------|
| `PUBSUB_PROJECT_ID` | GCP project ID (or `GOOGLE_CLOUD_PROJECT`) |
| `PUBSUB_TOPIC_ID` | Default topic ID |
| `PUBSUB_SUBSCRIPTION_ID` | Default subscription ID |
| `GOOGLE_APPLICATION_CREDENTIALS` | Path to service account key file |

## Step script (publish only)

```python
import pubsubclient as pubsub

pubsub.Publish({"orderId": "123", "status": "created"})
```

## Ingress (pull → Core Auto event)

```python
import pubsubclient as pubsub
import ingress

ingress.RunBridge(pubsub.Pull, max_messages=5, timeout_sec=30)
```

Requires `CA_EVENT_NAME`, `ENV`, `CA_ACCESS_CODE`, `CA_WBS_URL` — see [ingress README](../ingress/Python/README.md).

## API

| Function | Use |
|----------|-----|
| `Init()` | Verify project ID |
| `Publish(value, topic=None)` | **Steps** — publish to topic |
| `Pull(...)` | **Ingress only** — pull and acknowledge (requires `PUBSUB_SUBSCRIPTION_ID`) |

## License

Apache License 2.0 — see [LICENSE](../../../LICENSE).
