# cawbs — C client for the Core Auto Collector

Part of **coreauto-scripts-pub**. Not related to **coreauto-mngr-pub**.

## Layout

| Path | Purpose |
|------|---------|
| **`include/wbs.h`** | Shared session and result types |
| **`include/cawbs.h`** | Real-time API |
| **`include/cawbsbatch.h`** | Batch API |
| **`src/`** | Implementation |
| **`libcawbs.a`** | Static library (after `make`) |

## Prerequisites

- **GCC** or **Clang**
- **libcurl** development headers
- **libcjson** development headers

macOS (Homebrew):

```shell
brew install curl libcjson
```

Debian/Ubuntu:

```shell
sudo apt install libcurl4-openssl-dev libcjson-dev
```

## Build

```shell
cd cawbs/C
make
```

Link step scripts with:

```shell
gcc -Iinclude mystep.c -L. -lcawbs -lcurl -lcjson -o mystep
```

## Usage

```c
#include "cawbs.h"
#include <stdio.h>

int main(void) {
    wbs_result r = cawbs_init();
    if (r.status_code != 200) {
        fprintf(stderr, "%s\n", r.error ? r.error : "error");
        wbs_result_free(&r);
        return 1;
    }
    wbs_result_free(&r);

    r = cawbs_get_event_payload();
    if (r.payload) {
        printf("%s\n", r.payload);
    }
    wbs_result_free(&r);
    return 0;
}
```

Call **`wbs_result_free()`** on every result. Payload and answer fields are JSON strings.

## API

| Function | Description |
|----------|-------------|
| `cawbs_init()` | Authenticate (real-time env vars) |
| `cawbs_get_event_payload()` | Inbound event payload |
| `cawbs_put_step_payload(json)` | Store step output |
| `cawbs_get_step_payload(stepname)` | Prior step payload |
| `cawbs_get_keystore(keylist)` | Keystore secrets |
| `cawbsbatch_init()` | Authenticate (batch env vars) |
| `cawbsbatch_get_keystore(keylist)` | Keystore secrets |

## Environment variables

Real-time: `ENV`, `ACTIONID`, `CA_ACCESS_CODE`, `CA_WBS_URL`, `STEPNAME`

Batch: `ENV`, `CA_ACCESS_CODE`, `CA_WBS_URL`

## Documentation

- [Core Auto resources](https://coreauto.coredf.com/resources)
