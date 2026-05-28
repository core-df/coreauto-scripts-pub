# ibmmq — Go IBM MQ helpers for Core Auto

**Put** from step scripts. **Get** is for [ingress](../ingress/Go/README.md) bridges only.

Go equivalent of Python **pymqi**: [github.com/ibm-messaging/mq-golang](https://github.com/ibm-messaging/mq-golang).

## Module

`github.com/core-df/coreauto-scripts-pub/queues/ibmmq/Go`

## Build

Default build provides env validation and returns a clear error from `Put`/`Get` when IBM MQ client libraries are not linked.

To enable full IBM MQ support:

1. Install the [IBM MQ redistributable client](https://www.ibm.com/docs/en/ibm-mq/latest).
2. Build with the `ibmmq` tag:

```shell
cd queues/ibmmq/Go
go build -tags ibmmq ./...
```

Add to `go.mod` when using `-tags ibmmq`:

```
require github.com/ibm-messaging/mq-golang/v5 v5.5.3
```

## Environment variables

| Variable | Description |
|----------|-------------|
| `MQ_HOST` | Queue manager host |
| `MQ_PORT` | Port (default `1414`) |
| `MQ_QUEUE_MANAGER` | Queue manager name |
| `MQ_CHANNEL` | Channel (default `SYSTEM.DEF.SVRCONN`) |
| `MQ_USER` / `MQ_PASSWORD` | Optional credentials |
| `MQ_QUEUE` | Default queue name |

## License

Apache License 2.0 — see [LICENSE](../../../LICENSE).
