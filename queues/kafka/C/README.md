# Kafka client (C)

[librdkafka](https://github.com/confluentinc/librdkafka)-based client aligned with [Python](../Python/kafkaclient.py) and [Go](../Go/kafkaclient/kafkaclient.go).

## API

| Function | Purpose |
|----------|---------|
| `kafka_init()` | Verify `KAFKA_BOOTSTRAP_SERVERS` |
| `kafka_produce(topic, value, key)` | Publish from step scripts (`value` = UTF-8 or JSON text) |
| `kafka_consume(topic, timeout_sec, max_messages, group_id)` | Poll messages (ingress bridges only) |

## Environment

| Variable | Required | Notes |
|----------|----------|-------|
| `KAFKA_BOOTSTRAP_SERVERS` | Yes | Broker list |
| `KAFKA_SECURITY_PROTOCOL` | No | e.g. `SASL_SSL` |
| `KAFKA_SASL_MECHANISM` | No | |
| `KAFKA_SASL_USERNAME` / `KAFKA_SASL_PASSWORD` | No | |
| `KAFKA_GROUP_ID` | No | Consumer group (default `coreauto-step`) |
| `KAFKA_AUTO_OFFSET_RESET` | No | Default `earliest` |

## Build

```bash
brew install librdkafka cjson   # macOS
make
make test
```

Optional live broker test:

```bash
export KAFKA_INTEGRATION=1
export KAFKA_BOOTSTRAP_SERVERS=localhost:9092
make test
```

## Link

```bash
gcc -Iqueues/kafka/C/include -Ihttp/C/include -Lqueues/kafka/C -lcoreauto_kafka \
  -Lhttp/C -lcoreauto_http -lcjson -lrdkafka your_step.c
```
