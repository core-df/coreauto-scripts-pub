# cawbs — Java client for the Core Auto Collector

Part of **coreauto-scripts-pub**. Not related to **coreauto-mngr-pub**.

## Layout

| Class | Purpose |
|-------|---------|
| **`Cawbs`** | Real-time step API |
| **`CawbsBatch`** | Batch: auth + keystore |
| **`WbsSession`** | Shared HTTP session |
| **`Result`** | Return type (`getStatusCode()`, `getPayload()`, …) |

## Prerequisites

- **Java 11+**
- **Maven 3**
- No third-party dependencies (stdlib `HttpClient` + minimal JSON helper)

## Build

```shell
cd cawbs/Java
mvn -q compile
```

## Usage

```java
import com.coredf.cawbs.Cawbs;
import com.coredf.cawbs.Result;

Result result = Cawbs.Init();
if (result.getStatusCode() != 200) {
    throw new RuntimeException(result.getError().toString());
}

Result event = Cawbs.GetEventPayload();
Cawbs.PutStepPayload(java.util.Map.of("status", "ok"));
```

## Environment variables

Real-time: `ENV`, `ACTIONID`, `CA_ACCESS_CODE`, `CA_WBS_URL`, `STEPNAME`

Batch: `ENV`, `CA_ACCESS_CODE`, `CA_WBS_URL`

## Documentation

- [Core Auto resources](https://coreauto.coredf.com/resources)
