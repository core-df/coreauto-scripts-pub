# ingress — C

Queue → Core Auto bridge: consume from a queue backend, then submit events via **cawbsingress**.

## API

| Function | Description |
|----------|-------------|
| `ingress_trigger_event` | `POST /v1/rtevent` (payload JSON; `CA_EVENT_NAME` or `event_name`) |
| `ingress_forward_messages` | Map a consume result JSON to forwarded events |

Requires [cawbs/C](../../../cawbs/C/README.md) for Collector calls.

## Build & test

```shell
cd queues/ingress/C
make test
```

Tests cover missing `CA_EVENT_NAME` and consume error forwarding (no live queue or Collector).

Apache License 2.0.
