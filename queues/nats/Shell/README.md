# nats — Shell queue client for Core Auto

**Publish** from step scripts; **Subscribe** for [ingress](../ingress/Shell/README.md) bridges only.

## Prerequisites

- bash, jq
- nats CLI or python3+nats-py

## Usage

```bash
source /path/to/queues/nats/Shell/natsclient.sh
Init
Publish ...
# Ingress bridge:
Subscribe ...
RunBridge Subscribe ...
```

Sets **`NATS_RESULT`** and **`QUEUE_RESULT`** (after consume). Status codes: `200`, `601`, `0`.

## License

Apache License 2.0 — see [LICENSE](../../../LICENSE).
