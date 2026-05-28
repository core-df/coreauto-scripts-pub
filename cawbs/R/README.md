# cawbs — R client for the Core Auto Collector

Part of **coreauto-scripts-pub**. Not related to **coreauto-mngr-pub**.

## Files

| File | Use case |
|------|----------|
| **`cawbs.R`** | Real-time steps |
| **`cawbsbatch.R`** | Batch: auth + keystore |
| **`wbs.R`** | Shared HTTP helpers |

## Prerequisites

- **R 4.0+**
- **`httr`** and **`jsonlite`**

```r
install.packages(c("httr", "jsonlite"))
```

## Usage

```r
source("/path/to/cawbs/R/cawbs.R")

result <- Init()
if (result$status_code != 200) stop(result$error)

event <- GetEventPayload()
PutStepPayload(list(status = "ok"))
```

## Environment variables

Real-time: `ENV`, `ACTIONID`, `CA_ACCESS_CODE`, `CA_WBS_URL`, `STEPNAME`

Batch: `ENV`, `CA_ACCESS_CODE`, `CA_WBS_URL`

## Documentation

- [Core Auto resources](https://coreauto.coredf.com/resources)
