# queues — shared C helpers

| Path | Purpose |
|------|---------|
| [`common/queue_util.h`](common/queue_util.h) | `queue_ok200()`, `env_nonempty()` for backend `*_init()` |

Each backend has `queues/<backend>/C/` with `make test`. **Kafka** is the only backend with full produce/consume in C ([`kafka/C/README.md`](../kafka/C/README.md)). Ingress bridge: [`ingress/C/README.md`](../ingress/C/README.md).

See [queues README](../README.md) for the full language matrix.
