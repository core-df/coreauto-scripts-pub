# cawbs — Rust client for the Core Auto Collector

Part of **coreauto-scripts-pub**. Not related to **coreauto-mngr-pub**.

## Crates

| Module | Purpose |
|--------|---------|
| **`cawbs::Cawbs`** | Real-time step API |
| **`cawbs::CawbsBatch`** | Batch: auth + keystore |
| **`cawbs::Result`** | Return type |

## Prerequisites

- **Rust 1.70+** (for `OnceLock`)
- Dependencies: `ureq`, `serde`, `serde_json`

## Build

```shell
cd cawbs/Rust
cargo build
```

Add to your script `Cargo.toml`:

```toml
[dependencies]
cawbs = { path = "../path/to/cawbs/Rust" }
serde_json = "1"
```

## Usage

```rust
use cawbs::Cawbs;
use serde_json::json;

let result = Cawbs::init();
if result.status_code != 200 {
    panic!("{:?}", result.error);
}

let event = Cawbs::get_event_payload();
Cawbs::put_step_payload(json!({"status": "ok"}));
```

## Environment variables

Real-time: `ENV`, `ACTIONID`, `CA_ACCESS_CODE`, `CA_WBS_URL`, `STEPNAME`

Batch: `ENV`, `CA_ACCESS_CODE`, `CA_WBS_URL`

## Documentation

- [Core Auto resources](https://coreauto.coredf.com/resources)
