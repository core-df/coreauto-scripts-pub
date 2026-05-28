# rabbit — Shell queue client for Core Auto

**Publish** from step scripts; **Consume** for [ingress](../ingress/Shell/README.md) bridges only.

## Prerequisites

- bash, jq
- rabbitmqadmin or python3+pika

## Usage

```bash
source /path/to/queues/rabbit/Shell/rabbitclient.sh
Init
Publish ...
# Ingress bridge:
Consume ...
RunBridge Consume ...
```

Sets **`RABBIT_RESULT`** and **`QUEUE_RESULT`** (after consume). Status codes: `200`, `601`, `0`.

## License

Apache License 2.0 — see [LICENSE](../../../LICENSE).
