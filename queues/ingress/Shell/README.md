# ingress — Shell queue → Core Auto event bridge

Long-running ingress processes consume from a queue and call **cawbsingress** `PostEvent`.

## Prerequisites

- bash, jq
- [cawbsingress Shell](../../../cawbs/Shell/cawbsingress.sh)
- Queue client sourced in the same shell session

## Environment

`ENV`, `CA_ACCESS_CODE`, `CA_WBS_URL`, `CA_EVENT_NAME`, optional `CA_EVENT_SOURCE`, `CAWBS_SHELL`

## Usage

```bash
source /path/to/cawbs/Shell/cawbsingress.sh
source /path/to/queues/kafka/Shell/kafkaclient.sh
source /path/to/queues/ingress/Shell/ingress.sh

RunBridge Consume orders 30 10
```

## API

| Function | Description |
|----------|-------------|
| `TriggerEvent payload [event_name] [event_source]` | POST /v1/rtevent |
| `ForwardMessages consume_result_json` | Map messages → events |
| `RunBridge consume_fn ...` | Consume once + forward |

## License

Apache License 2.0 — see [LICENSE](../../../LICENSE).
