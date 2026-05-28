# files — Swift local file helpers for Core Auto steps

Read, write, and move files on the local filesystem. Part of **coreauto-scripts-pub**.

## Prerequisites

- macOS 12+ (Swift 5.9+)
- `swift build` in this directory

## Usage

```swift
import Files

let read = Fileclient.LocalRead("/data/inbox/order.csv")
// ["status_code": 200, "content": "..."]

Fileclient.LocalWrite("/data/out/ack.json", content: #"{"ok":true}"#)
Fileclient.LocalMove("/data/inbox/order.csv", "/data/processing/order.csv")
```

Functions return `[String: Any]` with `status_code`. Local I/O errors use `500`.

## API

| Function | Description |
|----------|-------------|
| `LocalRead(path, encoding)` | Read text file (UTF-8) |
| `LocalWrite(path, content, encoding)` | Write text; creates parent directories |
| `LocalMove(src, dest)` | Rename/move file |

## SFTP

SFTP (`SftpGet`, `SftpPut`, `SftpList`) is **not** implemented in this Swift port. Use [Python](../Python/README.md), [Kotlin](../Kotlin/README.md), or another language port for SFTP.

See [Python](../Python/README.md) for the full API reference.

## License

Apache License 2.0 — see [LICENSE](../../LICENSE).
