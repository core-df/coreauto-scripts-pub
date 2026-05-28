# s3 — Go S3 helpers for Core Auto steps

S3-compatible object storage helpers (AWS S3, MinIO, etc.).

## Module

`github.com/core-df/coreauto-scripts-pub/s3/Go`

## Environment variables

| Variable | Description |
|----------|-------------|
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | Credentials (or `AWS_PROFILE`) |
| `AWS_REGION` | Region (default `us-east-1`) |
| `S3_BUCKET` | Default bucket |
| `S3_ENDPOINT_URL` | Optional custom endpoint (MinIO) |

## API

| Function | Description |
|----------|-------------|
| `Init()` | Verify credentials and bucket |
| `GetObject(key, bucket)` | Download object |
| `PutObject(key, content, bucket)` | Upload object |
| `ListObjects(prefix, bucket)` | List keys |

## License

Apache License 2.0 — see [LICENSE](../../LICENSE).
