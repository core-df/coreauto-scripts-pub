# ingress — Go queue → Core Auto event bridge

Long-running **ingress processes** read from a message queue and call **`cawbsingress.PostEvent`** so Core Auto starts a real-time workflow. This is **not** for step scripts.

## Module

`github.com/core-df/coreauto-scripts-pub/queues/ingress/Go`

## Prerequisites

- **Go** 1.22 or later
- [`cawbs/Go/cawbsingress`](../../../cawbs/Go/cawbsingress)
- A queue client module (e.g. [`queues/kafka/Go`](../kafka/Go))

## Environment variables

| Variable | Description |
|----------|-------------|
| `ENV` | Core Auto environment |
| `CA_ACCESS_CODE` | Collector API code |
| `CA_WBS_URL` | Collector base URL |
| `CA_EVENT_NAME` | Event definition name |
| `CA_EVENT_SOURCE` | Optional `eventSource` field |

Plus queue backend env vars (see that backend's README).

## Usage

Kafka example:

```go
package main

import (
	"log"

	"github.com/core-df/coreauto-scripts-pub/queues/ingress/Go/ingressclient"
	"github.com/core-df/coreauto-scripts-pub/queues/kafka/Go/internal/result"
	"github.com/core-df/coreauto-scripts-pub/queues/kafka/Go/kafkaclient"
)

func main() {
	bridge := func() ingressclient.ConsumeResult {
		r := kafkaclient.Consume("orders", 30, 10, "")
		return toIngressConsume(r)
	}
	out := ingressclient.RunBridge(bridge)
	if out.StatusCode >= 400 {
		log.Fatal(out.Error)
	}
}

func toIngressConsume(r result.Result) ingressclient.ConsumeResult {
	msgs, _ := r.Messages.([]map[string]any)
	out := ingressclient.ConsumeResult{StatusCode: r.StatusCode, Error: r.Error}
	for _, m := range msgs {
		out.Messages = append(out.Messages, ingressclient.ConsumeMessage{Value: m["value"]})
	}
	return out
}
```

## API

| Function | Description |
|----------|-------------|
| `TriggerEvent(payload, eventName, eventSource)` | POST /v1/rtevent via cawbsingress |
| `ForwardMessages(consumeResult)` | Map queue messages → events |
| `RunBridge(consumeFn)` | Consume once + forward |

## License

Apache License 2.0 — see [LICENSE](../../../LICENSE).
