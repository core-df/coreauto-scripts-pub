# files — C

Local filesystem helpers (JSON results). See [Python](../Python/README.md) for full API; C port covers local read/write/move only.

## Build

```shell
cd files/C
make
make test
```

## API

| Function | Description |
|----------|-------------|
| `file_local_read` | Read file → `{status_code, content}` |
| `file_local_write` | Write file |
| `file_local_move` | Rename/move (destination parent must exist) |

## Tests

Temp files under `/tmp`; no network.

Apache License 2.0.
