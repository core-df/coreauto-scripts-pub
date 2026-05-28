# files — Rust local file helpers for Core Auto steps

Read, write, and move files on the local filesystem. Part of **coreauto-scripts-pub**.

## Prerequisites

- Rust 1.70+
- `cargo build` in this directory

## Usage

```rust
use coreauto_files::{local_read, local_write, local_move};

let result = local_read("/data/inbox/order.csv");
// { "status_code": 200, "content": "..." }

local_write("/data/out/ack.json", r#"{"ok":true}"#)?;
local_move("/data/inbox/order.csv", "/data/processing/order.csv")?;
```

Functions return `serde_json::Value` with `status_code`. Local I/O errors use `500`; missing env uses `601` (see `result` module).

## API

| Function | Description |
|----------|-------------|
| `local_read(path)` | Read text file as UTF-8 string |
| `local_write(path, content)` | Write text; creates parent directories |
| `local_move(src, dest)` | Rename/move file |

## SFTP

SFTP (`SftpGet`, `SftpPut`, `SftpList`) is **not** implemented in this Rust port. There is no lightweight, well-maintained SFTP crate that fits the same “stdlib-style” footprint as the Python `paramiko` helpers. Use [Python](../Python/README.md), [Kotlin](../Kotlin/README.md), or another language port for SFTP, or add a dedicated SFTP dependency in your step project.

## License

Apache License 2.0 — see [LICENSE](../../LICENSE).
