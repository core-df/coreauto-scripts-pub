# files — Go file and SFTP helpers for Core Auto steps

Local file operations and SFTP transfer helpers.

## Module

`github.com/core-df/coreauto-scripts-pub/files/Go`

## Prerequisites

- **Go** 1.22 or later
- `github.com/pkg/sftp` and `golang.org/x/crypto` for SFTP

## Environment variables (SFTP)

| Variable | Description |
|----------|-------------|
| `SFTP_HOST` | Remote host |
| `SFTP_USER` | Username |
| `SFTP_PASSWORD` | Password (or use key) |
| `SFTP_PRIVATE_KEY` | Path to private key file |
| `SFTP_PORT` | Default `22` |

## API

| Function | Description |
|----------|-------------|
| `LocalRead(path, encoding)` | Read text file |
| `LocalWrite(path, content, encoding)` | Write text file |
| `LocalMove(src, dest)` | Move/rename |
| `SftpGet(remote, local)` | Download |
| `SftpPut(local, remote)` | Upload |
| `SftpList(remoteDir)` | List directory |

## License

Apache License 2.0 — see [LICENSE](../../LICENSE).
