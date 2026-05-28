# cawbs — Node.js client for the Core Auto Collector

Part of **coreauto-scripts-pub**. Not related to **coreauto-mngr-pub**.

## Modules

| Module | Use case |
|--------|----------|
| **`cawbs.js`** | Real-time steps |
| **`cawbsbatch.js`** | Batch: auth + keystore |

## Prerequisites

- **Node.js 18+** (native `fetch`)
- No npm dependencies

## Usage

```javascript
import { Init, GetEventPayload, PutStepPayload } from './cawbs.js';

const result = await Init();
if (result.status_code !== 200) throw new Error(JSON.stringify(result));

const event = await GetEventPayload();
await PutStepPayload({ status: 'ok' });
```

Functions are **async** and return plain objects with `status_code`, `error`, `payload`, and `answer` fields.

## Environment variables

Real-time: `ENV`, `ACTIONID`, `CA_ACCESS_CODE`, `CA_WBS_URL`, `STEPNAME`

Batch: `ENV`, `CA_ACCESS_CODE`, `CA_WBS_URL`

## Documentation

- [Core Auto resources](https://coreauto.coredf.com/resources)
