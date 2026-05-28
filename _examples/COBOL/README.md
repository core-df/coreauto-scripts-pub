# Full integration example (COBOL)

COBOL steps typically call the [cawbs COBOL bridge](../../cawbs/COBOL/README.md). This folder provides a **shell driver** that runs the same scenario using Shell snippet libraries (equivalent flow to Python).

```shell
bash run_full_integration_step.sh
```

For a native COBOL step, copy patterns from `cawbs/COBOL/src/cawbs_rt.cbl` and invoke `FILELOCALWRITE` / transform helpers via the C bridge.

**Ingress:** use [Python](../Python/full_integration_ingress.py) or [Shell](../Shell/full_integration_ingress.sh).

Apache License 2.0.
