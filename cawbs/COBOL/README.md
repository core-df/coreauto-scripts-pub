# cawbs — COBOL client for the Core Auto Collector

Part of **coreauto-scripts-pub**. Not related to **coreauto-mngr-pub**.

COBOL step programs call a **C bridge** (`libcawbs_cobol.so`) that wraps the [C cawbs client](../C/README.md).

Target compiler: **GnuCOBOL** (`cobc`).

## Layout

| Path | Purpose |
|------|---------|
| **`src/cawbs_cobol.c`** | COBOL-callable C entry points |
| **`copy/CAWBSWS.cpy`** | Working-storage copybook |
| **`src/cawbs_rt.cbl`** | Real-time example program |
| **`src/cawbs_batch.cbl`** | Batch example program |
| **`libcawbs_cobol.so`** | Shared bridge library (after `make`) |

## Prerequisites

- **GnuCOBOL** (`cobc`)
- **GCC**
- **libcurl** and **libcjson** (same as the C client)

## Build

```shell
cd cawbs/COBOL
make
```

Produces `bin/cawbs_rt`, `bin/cawbs_batch`, and `bin/cawbs_ingress`.

## C bridge entry points

| Entry point | Description |
|-------------|-------------|
| `CAWBSRTINIT` | Authenticate (real-time env vars) |
| `CAWBSRTGETEVENT` | Inbound event payload |
| `CAWBSRTPUTSTEP` | Store step output (JSON string) |
| `CAWBSRTGETSTEP` | Prior step payload |
| `CAWBSRTGETKS` | Keystore secrets |
| `CAWBSBATCHINIT` | Authenticate (batch env vars) |
| `CAWBSBATCHGETKS` | Keystore secrets |
| `CAWBSINGRESSINIT` | Authenticate (ingress env vars) |
| `CAWBSINGRESSPOSTEVENT` | Submit real-time event |
| `CAWBSINGRESSGETSTATUS` | Event status by action ID |
| `CAWBSINGRESSGETLIST` | List events |
| `CAWBSINGRESSSUBMITFLAG` | Submit batch flag |
| `CAWBSINGRESSGETKS` | Keystore secrets |

Include **`copy/CAWBSWS.cpy`** in your program and `CALL` the entry points `USING` the copybook fields.

## Usage (real-time)

```cobol
       COPY "CAWBSWS.cpy".
       CALL "CAWBSRTINIT" USING CAWBS-STATUS CAWBS-ERROR
       IF CAWBS-STATUS NOT = 200
           DISPLAY "Init failed: " CAWBS-ERROR
           STOP RUN
       END-IF
       CALL "CAWBSRTGETEVENT" USING CAWBS-STATUS CAWBS-PAYLOAD CAWBS-ERROR
```

Set `COB_LIBRARY_PATH=.` (or install `libcawbs_cobol.so` on the loader path) when running compiled programs.

## Environment variables

Real-time: `ENV`, `ACTIONID`, `CA_ACCESS_CODE`, `CA_WBS_URL`, `STEPNAME`

Batch: `ENV`, `CA_ACCESS_CODE`, `CA_WBS_URL`

Ingress: `ENV`, `CA_ACCESS_CODE`, `CA_WBS_URL` (same as batch)

## Documentation

- [Core Auto resources](https://coreauto.coredf.com/resources)
