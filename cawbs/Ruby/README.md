# cawbs — Ruby client for the Core Auto Collector

Part of **coreauto-scripts-pub**. Not related to **coreauto-mngr-pub**.

## Modules

| Module | Use case |
|--------|----------|
| **`lib/cawbs.rb`** | Real-time steps |
| **`lib/cawbsbatch.rb`** | Batch: auth + keystore |

## Prerequisites

- **Ruby 2.7+**
- Standard library only (`net/http`, `json`)

## Usage

```ruby
$LOAD_PATH.unshift File.expand_path('lib', __dir__)
require 'cawbs'

result = Cawbs::Init
raise result.to_h.to_s unless result.status_code == 200

event = Cawbs::GetEventPayload
Cawbs::PutStepPayload('status' => 'ok')
```

Functions return `Wbs::Result` structs; call `#to_h` for a hash.

## Environment variables

Real-time: `ENV`, `ACTIONID`, `CA_ACCESS_CODE`, `CA_WBS_URL`, `STEPNAME`

Batch: `ENV`, `CA_ACCESS_CODE`, `CA_WBS_URL`

## Documentation

- [Core Auto resources](https://coreauto.coredf.com/resources)
