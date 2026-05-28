# files — Python file and SFTP helpers for Core Auto steps

Read/write/move local files and transfer via SFTP (file-arrival and partner-drop patterns).

## Prerequisites

- Python 3
- `pip install -r requirements.txt` (SFTP only; local ops use stdlib)

## Environment variables (SFTP)

| Variable | Description |
|----------|-------------|
| `SFTP_HOST` | Remote host |
| `SFTP_USER` | Username |
| `SFTP_PASSWORD` | Password (or use key) |
| `SFTP_PRIVATE_KEY` | Path to private key file |
| `SFTP_PORT` | Default `22` |

## Usage

```python
import fileclient as files

files.LocalRead("/data/inbox/order.csv")
files.LocalMove("/data/inbox/order.csv", "/data/processing/order.csv")

files.SftpGet("/incoming/report.csv", "/tmp/report.csv")
files.SftpPut("/tmp/ack.json", "/outgoing/ack.json")
```

## API

| Function | Description |
|----------|-------------|
| `LocalRead(path)` | Read text file |
| `LocalWrite(path, content)` | Write text file |
| `LocalMove(src, dest)` | Move/rename |
| `SftpGet(remote, local)` | Download |
| `SftpPut(local, remote)` | Upload |
| `SftpList(remote_dir=".")` | List directory |

## License

Apache License 2.0 — see [LICENSE](../../LICENSE).
