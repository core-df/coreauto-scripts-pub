# cawbs — Go client for the Core Auto Collector

**Core Auto Web Services library (cawbs)** provides HTTP access to the [Core Auto Collector](https://coreauto.coredf.com/resources) REST API from Go step scripts.

Part of **coreauto-scripts-pub**. Not related to **coreauto-mngr-pub** (PostgreSQL-backed agents and workers).

## Module layout

| Path | Package | Purpose |
|------|---------|---------|
| **`cawbs/`** | `cawbs` | Real-time steps: event payload, step payload read/write, keystore |
| **`cawbsbatch/`** | `cawbsbatch` | Batch scripts: authentication and keystore only |
| **`internal/wbs/`** | `wbs` | Shared HTTP and authentication helpers (not imported by scripts) |

Module path: **`github.com/core-df/coreauto-scripts-pub/cawbs/Go`**

## Prerequisites

- **Go** 1.22 or later (see **`go.mod`**)

No third-party dependencies — standard library only.

## Environment variables

### Real-time (`cawbs`)

| Variable | Description |
|----------|-------------|
| `ENV` | Target environment name (sent as the `Environment` header) |
| `ACTIONID` | Real-time action identifier for the current run |
| `CA_ACCESS_CODE` | API access code used to obtain a bearer token |
| `CA_WBS_URL` | Base URL of the Core Auto Collector web service |
| `STEPNAME` | Name of the current step (used by `PutStepPayload`) |

### Batch (`cawbsbatch`)

| Variable | Description |
|----------|-------------|
| `ENV` | Target environment name |
| `CA_ACCESS_CODE` | API access code |
| `CA_WBS_URL` | Collector base URL |

## Usage

### Real-time step script

```go
package main

import (
	"fmt"
	"log"

	"github.com/core-df/coreauto-scripts-pub/cawbs/Go/cawbs"
)

func main() {
	result := cawbs.Init()
	if result.StatusCode != 200 {
		log.Fatal(result.Error)
	}

	event := cawbs.GetEventPayload()
	if event.StatusCode != 200 {
		log.Fatal(event.Error)
	}
	fmt.Println(event.Payload)

	if r := cawbs.PutStepPayload(map[string]any{"status": "ok"}); r.StatusCode != 200 {
		log.Fatal(r.Error)
	}

	prior := cawbs.GetStepPayload("PreviousStep")
	secrets := cawbs.GetKeystore("db_user,db_password")
	_ = prior
	_ = secrets
}
```

### Batch script

```go
package main

import (
	"log"

	"github.com/core-df/coreauto-scripts-pub/cawbs/Go/cawbsbatch"
)

func main() {
	result := cawbsbatch.Init()
	if result.StatusCode != 200 {
		log.Fatal(result.Error)
	}

	secrets := cawbsbatch.GetKeystore("db_user,db_password")
	if secrets.StatusCode != 200 {
		log.Fatal(secrets.Error)
	}
	dbUser := secrets.Answer["db_user"]
	_ = dbUser
}
```

## Build

Verify the module compiles:

```shell
cd cawbs/Go
go build ./...
```

To use in a local script without publishing the module, add a **`replace`** directive in your script's **`go.mod`**:

```go
replace github.com/core-df/coreauto-scripts-pub/cawbs/Go => /path/to/coreauto-scripts-pub/cawbs/Go
```

## API reference

All functions return **`wbs.Result`** with JSON-compatible fields matching the Python client:

```go
type Result struct {
    StatusCode int            `json:"status_code"`
    Error      any            `json:"error,omitempty"`
    Payload    any            `json:"payload,omitempty"`
    Answer     map[string]any `json:"answer,omitempty"`
}
```

| Function | Description |
|----------|-------------|
| `Init()` | Authenticate via `POST /v1/auth/apicode`. Must be called once before other functions. |
| `GetEventPayload()` | `GET /v1/rtevent/{actionId}` — inbound event payload (`cawbs` only) |
| `PutStepPayload(payload)` | `POST /v1/rtstep/payload` — store current step output (`cawbs` only) |
| `GetStepPayload(stepname)` | `GET /v1/rtstep/payload/{actionId}/{stepname}` (`cawbs` only) |
| `GetKeystore(keylist)` | `GET /v1/keystore/{keys}` — comma-separated key names |

## Status codes

| Code | Meaning |
|------|---------|
| `200` | Success (HTTP status from the Collector) |
| `601` | Required environment variable(s) not set |
| `602` | `Init()` already called |
| `603` | `Init()` not called |
| `605` | Requested keystore key not found |
| `4xx` / `5xx` | Collector API error (see `Error` field) |

On network or non-JSON responses, `Error` is the string `"inaccessible"`.

## Documentation

- [Core Auto resources](https://coreauto.coredf.com/resources)
