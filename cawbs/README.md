# cawbs — Core Auto Web Services client library

**Core Auto Web Services (cawbs)** is a multi-language client for the [Core Auto Collector](https://coreauto.coredf.com/resources) REST API. Step scripts use it to authenticate, read and write real-time payloads, and fetch keystore secrets during batch or real-time execution.

Part of **coreauto-scripts-pub**. Not related to **coreauto-mngr-pub** (PostgreSQL-backed agents and workers).

## Modules

Every language port provides three variants:

| Variant | Use case | API surface |
|---------|----------|-------------|
| **cawbs** | Real-time steps | `Init`, `GetEventPayload`, `PutStepPayload`, `GetStepPayload`, `GetEventStatus`, `GetActionIdByPayload`, `GetKeystore` |
| **cawbsbatch** | Batch steps | `Init`, `GetKeystore` |
| **cawbsingress** | Queue bridges, schedulers, external triggers | `Init`, `PostEvent`, `GetEventStatus`, `GetEventList`, `SubmitFlag`, `GetKeystore` |

## Environment variables

### Real-time (`cawbs`)

| Variable | Description |
|----------|-------------|
| `ENV` | Target environment name (sent as the `Environment` header) |
| `ACTIONID` | Real-time action identifier for the current run |
| `CA_ACCESS_CODE` | API access code used to obtain a bearer token |
| `CA_WBS_URL` | Base URL of the Core Auto Collector web service |
| `STEPNAME` | Name of the current step (used when storing step output) |

### Batch (`cawbsbatch`)

| Variable | Description |
|----------|-------------|
| `ENV` | Target environment name |
| `CA_ACCESS_CODE` | API access code |
| `CA_WBS_URL` | Collector base URL |

### Ingress (`cawbsingress`)

| Variable | Description |
|----------|-------------|
| `ENV` | Target environment name |
| `CA_ACCESS_CODE` | API access code |
| `CA_WBS_URL` | Collector base URL |

No `ACTIONID` or `STEPNAME` — used by queue bridges and other long-lived ingress processes.

## API endpoints

| Function | HTTP | Module |
|----------|------|--------|
| `Init` | `POST /v1/auth/apicode` | all |
| `GetEventPayload` | `GET /v1/rtevent/{actionId}` | cawbs |
| `PostEvent` | `POST /v1/rtevent` | cawbsingress |
| `GetEventStatus` | `GET /v1/rtevent/status/{actionid}` | cawbs, cawbsingress |
| `GetEventList` | `GET /v1/rtevent/list` | cawbsingress |
| `SubmitFlag` | `POST /v1/flag` | cawbsingress |
| `PutStepPayload` | `POST /v1/rtstep/payload` | cawbs |
| `GetStepPayload` | `GET /v1/rtstep/payload/{actionId}/{stepname}` | cawbs |
| `GetActionIdByPayload` | `GET /v1/rtstep/payload/actionid/{path}/{searchValue}` | cawbs |
| `GetKeystore` | `GET /v1/keystore/{keys}` | all |

Call **`Init` once** before any other function.

## Status codes

All implementations return a result object with at least `status_code`:

| Code | Meaning |
|------|---------|
| `200` | Success (HTTP status from the Collector) |
| `601` | Required environment variable(s) not set |
| `602` | `Init` already called |
| `603` | `Init` not called |
| `605` | Requested keystore key not found |
| `4xx` / `5xx` | Collector API error (see `error` field) |
| `0` | Transport failure (where applicable) |

On network or non-JSON HTTP responses, `error` is typically the string `"inaccessible"`.

## Language implementations

| Language | Directory | Notes |
|----------|-----------|-------|
| Python | [`Python/`](Python/README.md) | `cawbs`, `cawbsbatch`, `cawbsingress` |
| Go | [`Go/`](Go/README.md) | `cawbs`, `cawbsbatch`, `cawbsingress` packages |
| Shell (bash) | [`Shell/`](Shell/README.md) | `cawbs.sh`, `cawbsbatch.sh`, `cawbsingress.sh` |
| C | [`C/`](C/README.md) | libcurl, libcjson; static library |
| Node.js | [`Node/`](Node/README.md) | Node 18+ `fetch`; async API |
| Java | [`Java/`](Java/README.md) | Maven, Java 11+ |
| C# / .NET | [`DotNet/`](DotNet/README.md) | .NET 8; async API |
| Kotlin | [`Kotlin/`](Kotlin/README.md) | Gradle, JVM 11+ |
| Scala | [`Scala/`](Scala/README.md) | sbt, Scala 3 |
| Swift | [`Swift/`](Swift/README.md) | SwiftPM, macOS 12+ |
| Rust | [`Rust/`](Rust/README.md) | `ureq`, `serde_json` |
| Ruby | [`Ruby/`](Ruby/README.md) | stdlib only |
| PHP | [`PHP/`](PHP/README.md) | curl extension |
| Perl | [`Perl/`](Perl/README.md) | `LWP::UserAgent`, `JSON` |
| R | [`R/`](R/README.md) | `httr`, `jsonlite` |
| Lua | [`Lua/`](Lua/README.md) | `curl` on `PATH` |
| Dart | [`Dart/`](Dart/README.md) | `http` package; async API |
| COBOL | [`COBOL/`](COBOL/README.md) | GnuCOBOL; C bridge to [`C/`](C/README.md) |

Pick the folder for your step script language and follow that README for prerequisites, build steps, and usage examples. Languages with **cawbsbatch** also provide **cawbsingress** (same env vars as batch: `ENV`, `CA_ACCESS_CODE`, `CA_WBS_URL`).

## Typical real-time flow

```
Init  →  GetEventPayload  →  (process)  →  PutStepPayload
                ↓
         GetStepPayload (optional, prior step)
                ↓
         GetKeystore (optional, secrets)
```

Batch scripts: **`Init`** → **`GetKeystore`**.

Queue ingress (not a step): **`cawbsingress.Init`** → **`PostEvent`** — see [`queues/ingress`](../queues/ingress/Python/README.md).

## Documentation

- [Core Auto resources](https://coreauto.coredf.com/resources)

## License

Copyright Core DF. Licensed under the [Apache License, Version 2.0](../../LICENSE).

Source files include the standard Apache 2.0 header from the repository [`LICENSE`](../../LICENSE) appendix.
