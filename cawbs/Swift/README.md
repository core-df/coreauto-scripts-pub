# cawbs — Swift client for the Core Auto Collector

Part of **coreauto-scripts-pub**. Not related to **coreauto-mngr-pub**.

## Layout

| Type | Purpose |
|------|---------|
| **`Cawbs`** | Real-time step API |
| **`CawbsBatch`** | Batch: auth + keystore |
| **`WbsSession`** | Shared HTTP session |
| **`Result`** | Return type |

## Prerequisites

- **Swift 5.9+**
- **macOS 12+** (or adjust `Package.swift` platforms)

## Build

```shell
cd cawbs/Swift
swift build
```

## Usage

```swift
import Cawbs

let result = Cawbs.initSession()
guard result.statusCode == 200 else { fatalError("\(result.error!)") }

let event = Cawbs.getEventPayload()
_ = Cawbs.putStepPayload(["status": "ok"])
```

Note: `init` is reserved in Swift — the entry point is **`initSession()`**.

## Environment variables

Real-time: `ENV`, `ACTIONID`, `CA_ACCESS_CODE`, `CA_WBS_URL`, `STEPNAME`

Batch: `ENV`, `CA_ACCESS_CODE`, `CA_WBS_URL`

## Documentation

- [Core Auto resources](https://coreauto.coredf.com/resources)
