# cawbs — Kotlin client for the Core Auto Collector

Part of **coreauto-scripts-pub**. Not related to **coreauto-mngr-pub**.

## Layout

| Object | Purpose |
|--------|---------|
| **`Cawbs`** | Real-time step API |
| **`CawbsBatch`** | Batch: auth + keystore |
| **`WbsSession`** | Shared HTTP session |
| **`Result`** | Return type |

## Prerequisites

- **JDK 11+**
- **Gradle 8+**
- No third-party dependencies

## Build

```shell
cd cawbs/Kotlin
gradle build
```

## Usage

```kotlin
import com.coredf.cawbs.Cawbs

val result = Cawbs.init()
check(result.statusCode == 200) { result.error }

val event = Cawbs.getEventPayload()
Cawbs.putStepPayload(mapOf("status" to "ok"))
```

## Environment variables

Real-time: `ENV`, `ACTIONID`, `CA_ACCESS_CODE`, `CA_WBS_URL`, `STEPNAME`

Batch: `ENV`, `CA_ACCESS_CODE`, `CA_WBS_URL`

## Documentation

- [Core Auto resources](https://coreauto.coredf.com/resources)
