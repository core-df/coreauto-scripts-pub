# kafka — Shell queue client for Core Auto

**Produce** from step scripts; **Consume** for [ingress](../ingress/Shell/README.md) bridges only.

## Prerequisites

- bash, jq
- kafka-console-producer, kafka-console-consumer

## Usage

```bash
source /path/to/queues/kafka/Shell/kafkaclient.sh
Init
Produce ...
# Ingress bridge:
Consume ...
RunBridge Consume ...
```

Sets **`KAFKA_RESULT`** and **`QUEUE_RESULT`** (after consume). Status codes: `200`, `601`, `0`.

## License

Apache License 2.0 — see [LICENSE](../../../LICENSE).
