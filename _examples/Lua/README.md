# Full integration example (Lua)

Port of [`Python/full_integration_step.py`](../Python/full_integration_step.py) — order-enrichment step using **cawbs**, **transform**, and **files**.

**Ingress:** not included in this folder — use [Python](../Python/full_integration_ingress.py), [Go](../Go/cmd/ingress/), [Shell](../Shell/full_integration_ingress.sh), or another language with `queues/ingress`.

## Run (smoke test)

```shell
export ENV=dev ACTIONID=1 STEPNAME=EnrichOrder
export CA_ACCESS_CODE=your-code CA_WBS_URL=http://collector:9100
lua full_integration_step.lua
```

## License

Apache License 2.0.
