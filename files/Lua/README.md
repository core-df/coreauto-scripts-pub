# files — Lua local file helpers for Core Auto steps

Read, write, and move files on the local filesystem. Part of **coreauto-scripts-pub**.

## Prerequisites

- Lua 5.x

Add this directory’s `lib/` folder to `LUA_PATH`, or run from the `lib` directory.

## Usage

```lua
local fileclient = require("fileclient")

fileclient.LocalRead("/data/inbox/order.csv")
fileclient.LocalWrite("/data/out/ack.json", '{"ok":true}')
fileclient.LocalMove("/data/inbox/order.csv", "/data/processing/order.csv")
```

## API

| Function | Description |
|----------|-------------|
| `LocalRead(path, encoding)` | Read text file (UTF-8) |
| `LocalWrite(path, content, encoding)` | Write text; creates parent directories |
| `LocalMove(src, dest)` | Rename/move file |

## SFTP

SFTP is **not** implemented in this Lua port. Use [Python](../Python/README.md) or [Kotlin](../Kotlin/README.md).

See [Python](../Python/README.md) for the full API reference.

## License

Apache License 2.0 — see [LICENSE](../../LICENSE).
