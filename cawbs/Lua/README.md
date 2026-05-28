# cawbs — Lua client for the Core Auto Collector

Part of **coreauto-scripts-pub**. Not related to **coreauto-mngr-pub**.

## Files

| File | Use case |
|------|----------|
| **`cawbs.lua`** | Real-time steps |
| **`cawbsbatch.lua`** | Batch: auth + keystore |
| **`lib/wbs.lua`** | Shared helpers (curl + minimal JSON) |

## Prerequisites

- **Lua 5.1+**
- **`curl`** on `PATH`

## Usage

```lua
local cawbs = dofile("/path/to/cawbs/Lua/cawbs.lua")

local result = cawbs.Init()
if result.status_code ~= 200 then error(result.error) end

local event = cawbs.GetEventPayload()
cawbs.PutStepPayload({ status = "ok" })
```

## Environment variables

Real-time: `ENV`, `ACTIONID`, `CA_ACCESS_CODE`, `CA_WBS_URL`, `STEPNAME`

Batch: `ENV`, `CA_ACCESS_CODE`, `CA_WBS_URL`

## Documentation

- [Core Auto resources](https://coreauto.coredf.com/resources)
