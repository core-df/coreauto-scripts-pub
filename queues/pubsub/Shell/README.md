# pubsub — Shell queue client for Core Auto

**Publish** from step scripts; **Pull** for [ingress](../ingress/Shell/README.md) bridges only.

## Prerequisites

- bash, jq
- gcloud or python3+google-cloud-pubsub

## Usage

```bash
source /path/to/queues/pubsub/Shell/pubsubclient.sh
Init
Publish ...
# Ingress bridge:
Pull ...
RunBridge Pull ...
```

Sets **`PUBSUB_RESULT`** and **`QUEUE_RESULT`** (after consume). Status codes: `200`, `601`, `0`.

## License

Apache License 2.0 — see [LICENSE](../../../LICENSE).
