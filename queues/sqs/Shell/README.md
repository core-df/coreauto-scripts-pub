# sqs — Shell queue client for Core Auto

**Send** from step scripts; **Receive** for [ingress](../ingress/Shell/README.md) bridges only.

## Prerequisites

- bash, jq
- AWS CLI

## Usage

```bash
source /path/to/queues/sqs/Shell/sqsclient.sh
Init
Send ...
# Ingress bridge:
Receive ...
RunBridge Receive ...
```

Sets **`SQS_RESULT`** and **`QUEUE_RESULT`** (after consume). Status codes: `200`, `601`, `0`.

## License

Apache License 2.0 — see [LICENSE](../../../LICENSE).
