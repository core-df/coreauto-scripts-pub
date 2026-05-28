# s3 — Python S3 object storage helpers for Core Auto steps

Get, put, and list objects in AWS S3 or S3-compatible stores (MinIO, etc.).

## Prerequisites

- Python 3
- `pip install -r requirements.txt`

## Environment variables

| Variable | Description |
|----------|-------------|
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | Credentials (or `AWS_PROFILE`) |
| `AWS_REGION` | Region (default `us-east-1`) |
| `S3_BUCKET` | Default bucket |
| `S3_ENDPOINT_URL` | Custom endpoint for MinIO / compatible APIs |

## Usage

```python
import s3client as s3

s3.Init()
s3.PutObject("reports/2024/summary.json", json.dumps(data))
result = s3.GetObject("reports/2024/summary.json")
keys = s3.ListObjects(prefix="reports/2024/")
```

## API

| Function | Description |
|----------|-------------|
| `Init()` | Verify credentials and default bucket |
| `GetObject(key, bucket=None)` | Download object |
| `PutObject(key, content, bucket=None)` | Upload text |
| `ListObjects(prefix="", bucket=None)` | List keys |

## License

Apache License 2.0 — see [LICENSE](../../LICENSE).
