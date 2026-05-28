# files — R local file helpers for Core Auto steps

Read, write, and move files on the local filesystem. Part of **coreauto-scripts-pub**.

## Prerequisites

- R 4.0+ (base R only)

## Usage

```r
source("fileclient.R")

LocalRead("/data/inbox/order.csv")
LocalWrite("/data/out/ack.json", '{"ok":true}')
LocalMove("/data/inbox/order.csv", "/data/processing/order.csv")
```

Functions return a list with `status_code`. Local I/O errors use `500`.

## API

| Function | Description |
|----------|-------------|
| `LocalRead(path, encoding)` | Read text file |
| `LocalWrite(path, content, encoding)` | Write text; creates parent directories |
| `LocalMove(src, dest)` | Rename/move file |

## SFTP

SFTP is **not** implemented in this R port. Use [Python](../Python/README.md) or [Kotlin](../Kotlin/README.md).

See [Python](../Python/README.md) for the full API reference.

## License

Apache License 2.0 — see [LICENSE](../../LICENSE).
