# C unit test harness

Shared helpers for library tests under `*/C/tests/`:

- `testutil.h` / `testutil.c` — assertions and JSON `status_code` checks
- `mock_http.c` — loopback HTTP server (fork) for curl-based clients

**Queues:** C clients under `queues/<backend>/C/` (shared helpers in [`queues/_shared/C/`](../queues/_shared/C/README.md)) provide `*_init()` env checks and **ingress** trigger/forward guards. **Kafka** implements full produce/consume via librdkafka; other backends are init-only unless extended.

Run from each `*/C` directory:

```bash
make test
```

Or all C suites from the repo root: `./run-library-tests.sh`

**Dependencies:** `gcc`, `libcjson`; `libcurl` (cawbs, http, notify); `librdkafka` (queues/kafka/C only).

**Libraries with C tests:** cawbs, files, http, notify, s3, transform, queues (all backends + ingress).
