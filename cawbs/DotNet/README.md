# cawbs — .NET client for the Core Auto Collector

Part of **coreauto-scripts-pub**. Not related to **coreauto-mngr-pub**.

## Layout

| Type | Purpose |
|------|---------|
| **`Cawbs`** | Real-time step API |
| **`CawbsBatch`** | Batch: auth + keystore |
| **`WbsSession`** | Shared HTTP session |
| **`Result`** | Return type |

## Prerequisites

- **.NET 8 SDK**
- No third-party NuGet packages

## Build

```shell
cd cawbs/DotNet
dotnet build
```

## Usage

```csharp
using CoreAuto.Cawbs;

var result = await Cawbs.InitAsync();
if (result.StatusCode != 200) throw new Exception(result.Error?.ToString());

var eventPayload = await Cawbs.GetEventPayloadAsync();
await Cawbs.PutStepPayloadAsync(new { status = "ok" });
```

API methods are **async** (`InitAsync`, `GetKeystoreAsync`, …).

## Environment variables

Real-time: `ENV`, `ACTIONID`, `CA_ACCESS_CODE`, `CA_WBS_URL`, `STEPNAME`

Batch: `ENV`, `CA_ACCESS_CODE`, `CA_WBS_URL`

## Documentation

- [Core Auto resources](https://coreauto.coredf.com/resources)
