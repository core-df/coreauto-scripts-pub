# queues — messaging helpers for Core Auto

Multi-language helpers for **outbound** messages from step scripts, plus an **ingress bridge** that turns queue messages into Core Auto events.

Part of **coreauto-scripts-pub**. Collector API access uses [**cawbs**](../cawbs/README.md).

## Step scripts vs ingress

| Role | Where it runs | Queue | Core Auto |
|------|---------------|-------|-----------|
| **Step** | One-shot per workflow step | **Produce / send / publish** only | Read event via `cawbs.GetEventPayload()`, write via `PutStepPayload()` |
| **Ingress** | Long-lived bridge process | **Consume / receive** | Submit via `cawbsingress.PostEvent()` → triggers real-time workflow |

Steps must not poll queues — they start when Core Auto invokes them and exit when done. Use [**ingress**](ingress/README.md) to consume from a queue and call the Collector.

```
External system → Queue → ingress (PostEvent) → Core Auto → step (GetEventPayload)
Step → Queue (Produce) → downstream system
```

## Tests

Python, Go, and C unit tests under `queues/<backend>/{Python,Go,C}/` (plus `ingress`). Python/Go mock brokers and cloud SDKs; C tests validate env wiring (and **Kafka** produce/consume when `KAFKA_INTEGRATION=1`). No live services required for the default suite. Run everything from the repo root with [`run-library-tests.sh`](../run-library-tests.sh).

## Language implementations

Each backend (`kafka`, `rabbit`, `sqs`, `redis`, `servicebus`, `nats`, `ibmmq`, `pubsub`) provides the same language folders as [**cawbs**](../cawbs/README.md), except COBOL (not applicable for messaging). **C** ports expose `Init()` and JSON helpers; **Kafka** also implements `Produce` / `Consume` via librdkafka. Other backends are init-only unless extended.

| Language | Typical path | Notes |
|----------|--------------|-------|
| Python | `queues/<backend>/Python/` | Reference implementation |
| Go | `queues/<backend>/Go/` | |
| C | `queues/<backend>/C/` | `*_init()` + tests; shared: [`_shared/C/`](_shared/C/README.md); **Kafka**: produce/consume ([`kafka/C/README.md`](kafka/C/README.md)); ingress: [`ingress/C/README.md`](ingress/C/README.md) |
| Shell (bash) | `queues/<backend>/Shell/` | |
| Node.js | `queues/<backend>/Node/` | |
| Java | `queues/<backend>/Java/` | Maven |
| Kotlin | `queues/<backend>/Kotlin/` | Gradle |
| Scala | `queues/<backend>/Scala/` | sbt |
| C# / .NET | `queues/<backend>/DotNet/` | |
| Rust | `queues/<backend>/Rust/` | rabbit, sqs, redis, nats full; others stub or partial |
| Ruby | `queues/<backend>/Ruby/` | |
| PHP | `queues/<backend>/PHP/` | |
| Perl | `queues/<backend>/Perl/` | |

**Ingress** (queue → `POST /v1/rtevent`): [`ingress/Python/`](ingress/Python/README.md), [`ingress/C/`](ingress/C/README.md), [`ingress/Shell/`](ingress/Shell/README.md), [`ingress/Node/`](ingress/Node/README.md), [`ingress/Go/`](ingress/Go/README.md), [`ingress/Java/`](ingress/Java/README.md), [`ingress/Kotlin/`](ingress/Kotlin/README.md), [`ingress/Scala/`](ingress/Scala/README.md), [`ingress/DotNet/`](ingress/DotNet/README.md).

Set `CA_EVENT_NAME` to the Core Auto event definition that should run when a message arrives.

## Backends — outbound (steps)

| Backend | Step API | Consume (ingress only) |
|---------|----------|--------------------------|
| **Kafka** | `Produce` | `Consume` |
| **RabbitMQ** | `Publish` | `Consume` |
| **Amazon SQS** | `Send` | `Receive` |
| **Redis** | `Push` | `Pop` |
| **Azure Service Bus** | `Send` | `Receive` |
| **NATS** | `Publish` | `Subscribe` |
| **IBM MQ** | `Put` | `Get` |
| **Google Pub/Sub** | `Publish` | `Pull` |

See each backend’s README under `queues/<backend>/<Language>/`.

## License

Copyright Core DF. Licensed under the [Apache License, Version 2.0](../LICENSE).
