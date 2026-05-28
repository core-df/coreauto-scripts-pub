# Full integration example (Scala)

Port of [`Python/full_integration_step.py`](../Python/full_integration_step.py) — order-enrichment step combining **cawbs**, **transform**, **files**, and Kafka produce.

| Source | Role |
|--------|------|
| `FullIntegrationStep.scala` | Core Auto step |
| `FullIntegrationIngress.scala` | Kafka → Collector bridge |

```shell
export CA_EVENT_NAME=OrderInbound KAFKA_BOOTSTRAP_SERVERS=localhost:9092
export EXAMPLE_KAFKA_TOPIC=orders.inbound
sbt "runMain com.coredf.examples.fullIntegrationIngress"
```

Add project dependencies on `cawbs/Scala`, `transform/Scala`, `files/Scala`, `queues/kafka/Scala`, `queues/ingress/Scala`.

## Run (smoke test)

```shell
export ENV=dev ACTIONID=1 STEPNAME=EnrichOrder
export CA_ACCESS_CODE=your-code CA_WBS_URL=http://collector:9100
sbt "runMain com.coredf.examples.fullIntegrationStep"
```

Set only env vars for integrations you use — others are skipped. See [Python README](../Python/README.md) for the full variable list.

## License

Apache License 2.0.
