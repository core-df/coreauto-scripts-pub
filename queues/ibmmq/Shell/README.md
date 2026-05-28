# ibmmq — Shell queue client for Core Auto

**Put** from step scripts; **Get** for [ingress](../ingress/Shell/README.md) bridges only.

## Prerequisites

- bash, jq
- python3+pymqi (IBM MQ client)

## Usage

```bash
source /path/to/queues/ibmmq/Shell/ibmmqclient.sh
Init
Put ...
# Ingress bridge:
Get ...
RunBridge Get ...
```

Sets **`IBMMQ_RESULT`** and **`QUEUE_RESULT`** (after consume). Status codes: `200`, `601`, `0`.

## License

Apache License 2.0 — see [LICENSE](../../../LICENSE).
