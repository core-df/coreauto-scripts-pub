# Full integration example (C)

Port of [`Python/full_integration_step.py`](../Python/full_integration_step.py) — order-enrichment step using **cawbs** and **files**.

**Ingress:** not included in this folder — use [Python](../Python/full_integration_ingress.py), [Go](../Go/cmd/ingress/), [Shell](../Shell/full_integration_ingress.sh), or another language with `queues/ingress`.

## Run (smoke test)

```shell
export ENV=dev ACTIONID=1 STEPNAME=EnrichOrder
export CA_ACCESS_CODE=your-code CA_WBS_URL=http://collector:9100
make && ./full_integration_step
```

## License

Apache License 2.0.
