# s3 — Lua S3 object storage helpers for Core Auto steps

Get, put, and list objects via the **AWS CLI** (`aws` on `PATH`). Part of **coreauto-scripts-pub**.

## Prerequisites

- Lua 5.x
- [AWS CLI v2](https://aws.amazon.com/cli/) installed and configured

Add this directory’s `lib/` folder to `LUA_PATH`.

## Environment variables

| Variable | Description |
|----------|-------------|
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | Credentials (or `AWS_PROFILE`) |
| `AWS_REGION` | Region (default `us-east-1`) |
| `S3_BUCKET` | Default bucket |
| `S3_ENDPOINT_URL` | Custom endpoint for MinIO / compatible APIs |

## Usage

```lua
local s3 = require("s3client")

s3.Init()
s3.PutObject("reports/summary.json", '{"ok":true}')
s3.GetObject("reports/summary.json")
s3.ListObjects("reports/")
```

## API

| Function | Description |
|----------|-------------|
| `Init()` | Verify credentials and default bucket |
| `GetObject(key, bucket_name)` | Download object as text |
| `PutObject(key, content, bucket_name)` | Upload text |
| `ListObjects(prefix, bucket_name)` | List keys |

See [Python](../Python/README.md) for the full API reference.

## License

Apache License 2.0 — see [LICENSE](../../LICENSE).
