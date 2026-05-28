# cawbs — Shell client for the Core Auto Collector

**Core Auto Web Services library (cawbs)** provides HTTP access to the [Core Auto Collector](https://coreauto.coredf.com/resources) REST API from shell step scripts.

Part of **coreauto-scripts-pub**. Not related to **coreauto-mngr-pub** (PostgreSQL-backed agents and workers).

## Scripts

| Script | Use case |
|--------|----------|
| **`cawbs.sh`** | Real-time steps: event payload, step payload read/write, keystore |
| **`cawbsbatch.sh`** | Batch scripts: authentication and keystore only |
| **`lib/wbs.sh`** | Shared HTTP and authentication helpers (sourced internally) |

Source **either** `cawbs.sh` or `cawbsbatch.sh` — not both in the same script (both define `Init` and `GetKeystore`).

## Prerequisites

- **bash**
- **`curl`**
- **`jq`**

## Environment variables

### Real-time (`cawbs.sh`)

| Variable | Description |
|----------|-------------|
| `ENV` | Target environment name (sent as the `Environment` header) |
| `ACTIONID` | Real-time action identifier for the current run |
| `CA_ACCESS_CODE` | API access code used to obtain a bearer token |
| `CA_WBS_URL` | Base URL of the Core Auto Collector web service |
| `STEPNAME` | Name of the current step (used by `PutStepPayload`) |

### Batch (`cawbsbatch.sh`)

| Variable | Description |
|----------|-------------|
| `ENV` | Target environment name |
| `CA_ACCESS_CODE` | API access code |
| `CA_WBS_URL` | Collector base URL |

## Usage

### Real-time step script

```bash
#!/usr/bin/env bash
set -euo pipefail

source /path/to/coreauto-scripts-pub/cawbs/Shell/cawbs.sh

Init
if [[ "$WBS_STATUS_CODE" != "200" ]]; then
  echo "$WBS_ERROR" >&2
  exit 1
fi

GetEventPayload
if [[ "$WBS_STATUS_CODE" != "200" ]]; then
  echo "$WBS_ERROR" >&2
  exit 1
fi
echo "$WBS_PAYLOAD" | jq .

PutStepPayload '{"status":"ok","count":42}'

GetStepPayload "PreviousStep"
GetKeystore "db_user,db_password"
db_user=$(echo "$WBS_ANSWER" | jq -r .db_user)
```

### Batch script

```bash
#!/usr/bin/env bash
set -euo pipefail

source /path/to/coreauto-scripts-pub/cawbs/Shell/cawbsbatch.sh

Init
if [[ "$WBS_STATUS_CODE" != "200" ]]; then
  echo "$WBS_ERROR" >&2
  exit 1
fi

GetKeystore "db_user,db_password"
if [[ "$WBS_STATUS_CODE" != "200" ]]; then
  echo "$WBS_ERROR" >&2
  exit 1
fi
db_user=$(echo "$WBS_ANSWER" | jq -r .db_user)
```

### JSON result variable

Each function sets **`WBS_RESULT`** to a JSON object matching the Python client return dict, for example:

```bash
Init
echo "$WBS_RESULT" | jq .
# {"status_code":200}
```

Convenience variables are also set:

| Variable | Description |
|----------|-------------|
| `WBS_STATUS_CODE` | Result status code |
| `WBS_ERROR` | Error message or JSON error body |
| `WBS_PAYLOAD` | Event or step payload (JSON) |
| `WBS_ANSWER` | Keystore response object (JSON) |

## API reference

All functions update **`WBS_RESULT`** and **`WBS_STATUS_CODE`**. They do not exit the script on error (same as the Python dict return values).

| Function | Description |
|----------|-------------|
| `Init` | Authenticate via `POST /v1/auth/apicode`. Must be called once before other functions. |
| `GetEventPayload` | `GET /v1/rtevent/{actionId}` — inbound event payload (`cawbs.sh` only) |
| `PutStepPayload <json>` | `POST /v1/rtstep/payload` — store current step output; argument must be valid JSON (`cawbs.sh` only) |
| `GetStepPayload <stepname>` | `GET /v1/rtstep/payload/{actionId}/{stepname}` (`cawbs.sh` only) |
| `GetKeystore <keylist>` | `GET /v1/keystore/{keys}` — comma-separated key names |

## Status codes

| Code | Meaning |
|------|---------|
| `200` | Success (HTTP status from the Collector) |
| `601` | Required environment variable(s) not set |
| `602` | `Init` already called |
| `603` | `Init` not called |
| `605` | Requested keystore key not found |
| `4xx` / `5xx` | Collector API error (see `WBS_ERROR`) |
| `0` | Transport failure (`curl` could not complete the request) |

On non-JSON HTTP error responses, `WBS_ERROR` is the string `"inaccessible"`.

## Documentation

- [Core Auto resources](https://coreauto.coredf.com/resources)
