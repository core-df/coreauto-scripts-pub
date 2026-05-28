# cawbs — Scala client for the Core Auto Collector

Part of **coreauto-scripts-pub**. Not related to **coreauto-mngr-pub**.

## Layout

| Object | Purpose |
|--------|---------|
| **`Cawbs`** | Real-time step API |
| **`CawbsBatch`** | Batch: auth + keystore |
| **`CawbsIngress`** | Ingress: submit events and flags |
| **`WbsSession`** | Shared HTTP session |
| **`Result`** | Return type |

## Prerequisites

- **Scala 3.3+**
- **sbt 1.9+**
- No third-party dependencies

## Build

```shell
cd cawbs/Scala
sbt compile
```

## Usage

```scala
import com.coredf.cawbs.Cawbs

val result = Cawbs.Init()
require(result.statusCode == 200, result.error)

val event = Cawbs.GetEventPayload()
Cawbs.PutStepPayload(Map("status" -> "ok"))

// Ingress
import com.coredf.cawbs.CawbsIngress

val ingress = CawbsIngress.Init()
CawbsIngress.PostEvent("OrderCreated", Map("orderId" -> "123"))
```

## Environment variables

Real-time: `ENV`, `ACTIONID`, `CA_ACCESS_CODE`, `CA_WBS_URL`, `STEPNAME`

Batch: `ENV`, `CA_ACCESS_CODE`, `CA_WBS_URL`

## Documentation

- [Core Auto resources](https://coreauto.coredf.com/resources)
