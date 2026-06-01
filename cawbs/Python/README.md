# cawbs — Python client for the Core Auto Collector

**Core Auto Web Services library (cawbs)** provides HTTP access to the [Core Auto Collector](https://coreauto.coredf.com/resources) REST API from Python step scripts.

Part of **coreauto-scripts-pub**. Not related to **coreauto-mngr-pub** (PostgreSQL-backed agents and workers).

## Modules

| Module | Use case |
|--------|----------|
| **`cawbs.py`** | Real-time steps: read/write payloads, keystore |
| **`cawbsbatch.py`** | Batch scripts: authentication and keystore only |
| **`cawbsingress.py`** | Ingress bridges: submit events and flags (no ACTIONID / STEPNAME) |

## Prerequisites

- **Python 3**
- **`requests`** — `pip install requests`

## Tests

Unit tests mock HTTP calls (no Collector required):

```shell
cd cawbs/Python
python3 -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements-dev.txt requests
python -m pytest tests/ -v
```

Place the module on `PYTHONPATH`, or copy it next to your script:

```shell
export PYTHONPATH="/path/to/coreauto-scripts-pub/cawbs/Python:${PYTHONPATH}"
```

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

### Ingress (`cawbsingress`)

| Variable | Description |
|----------|-------------|
| `ENV` | Target environment name |
| `CA_ACCESS_CODE` | API access code |
| `CA_WBS_URL` | Collector base URL |

## Usage

### Real-time step script

```python
import cawbs

result = cawbs.Init()
if result.get("status_code") != 200:
    raise RuntimeError(result)

event = cawbs.GetEventPayload()
if event.get("status_code") != 200:
    raise RuntimeError(event)

payload = event["payload"]

cawbs.PutStepPayload({"status": "ok", "count": 42})

prior = cawbs.GetStepPayload("PreviousStep")
secrets = cawbs.GetKeystore("db_user,db_password")
```

### Batch script

```python
import cawbsbatch

result = cawbsbatch.Init()
if result.get("status_code") != 200:
    raise RuntimeError(result)

secrets = cawbsbatch.GetKeystore("db_user,db_password")
db_user = secrets["answer"]["db_user"]
```

### Ingress bridge (queue → event)

```python
import cawbsingress

result = cawbsingress.Init()
cawbsingress.PostEvent("OrderCreated", {"orderId": "123"}, event_source="kafka-orders")
# → {status_code: 201, actionId: ..., eventId: ...}
```

See [`queues/ingress`](../../queues/ingress/Python/README.md) for combining with queue clients.

## API reference

All functions return a **dict** with at least `status_code`. On success, `status_code` is the HTTP status (typically `200`). Additional fields depend on the call.

| Function | Description |
|----------|-------------|
| `Init()` | Authenticate via `POST /v1/auth/apicode`. Must be called once before other functions. |
| `GetEventPayload()` | `GET /v1/rtevent/{actionId}` — inbound event payload |
| `PutStepPayload(payload)` | `POST /v1/rtstep/payload` — store current step output |
| `GetStepPayload(stepname)` | `GET /v1/rtstep/payload/{actionId}/{stepname}` |
| `GetEventStatus(action_id=None)` | `GET /v1/rtevent/status/{actionid}` |
| `GetActionIdByPayload(path, search_value)` | Lookup action by nested payload field |
| `GetKeystore(keylist)` | `GET /v1/keystore/{keys}` |

### cawbsingress

| Function | Description |
|----------|-------------|
| `Init()` | Authenticate (ENV, CA_ACCESS_CODE, CA_WBS_URL only) |
| `PostEvent(event_name, payload, event_source=None)` | `POST /v1/rtevent` — trigger workflow |
| `GetEventStatus(action_id)` | Poll run status |
| `GetEventList()` | List event definitions |
| `SubmitFlag(name, system_name, source_system_name, date)` | `POST /v1/flag` |
| `GetKeystore(keylist)` | Keystore access |

## Status codes

| Code | Meaning |
|------|---------|
| `200` / `201` | Success (HTTP status from the Collector; `PostEvent` returns `201`) |
| `601` | Required environment variable(s) not set |
| `602` | `Init()` already called |
| `603` | `Init()` not called |
| `605` | Requested keystore key not found |
| `4xx` / `5xx` | Collector API error (see `error` field) |

On network or non-JSON responses, `error` is the string `"inaccessible"`.

## Documentation

- [Core Auto resources](https://coreauto.coredf.com/resources)
