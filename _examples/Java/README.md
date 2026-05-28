# Full integration example (Java)

Port of [`Python/full_integration_step.py`](../Python/full_integration_step.py) — order-enrichment step combining **cawbs**, **transform**, **files**, and Kafka produce.

| Class | Role |
|-------|------|
| `FullIntegrationStep` | Core Auto step |
| `FullIntegrationIngress` | Kafka → Collector bridge |

```shell
export CA_EVENT_NAME=OrderInbound KAFKA_BOOTSTRAP_SERVERS=localhost:9092
export EXAMPLE_KAFKA_TOPIC=orders.inbound
mvn -q exec:java -Dexec.mainClass=com.coredf.examples.FullIntegrationIngress
```

## Run (smoke test)

```shell
export ENV=dev ACTIONID=1 STEPNAME=EnrichOrder
export CA_ACCESS_CODE=your-code CA_WBS_URL=http://collector:9100
mvn -q exec:java -Dexec.mainClass=com.coredf.examples.FullIntegrationStep
```

Install library JARs first: `mvn install` in each of `cawbs/Java`, `transform/Java`, `files/Java`, `queues/kafka/Java`, `queues/ingress/Java`.

Set only env vars for integrations you use — others are skipped. See [Python README](../Python/README.md) for the full variable list.

## License

Apache License 2.0.
