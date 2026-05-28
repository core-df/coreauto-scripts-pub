# redis — Shell queue client for Core Auto

**Push** from step scripts; **Pop** for [ingress](../ingress/Shell/README.md) bridges only.

## Prerequisites

- bash, jq
- redis-cli

## Usage

```bash
source /path/to/queues/redis/Shell/redisclient.sh
Init
Push ...
# Ingress bridge:
Pop ...
RunBridge Pop ...
```

Sets **`REDIS_RESULT`** and **`QUEUE_RESULT`** (after consume). Status codes: `200`, `601`, `0`.

## License

Apache License 2.0 — see [LICENSE](../../../LICENSE).
