# s3 — R S3 object storage helpers for Core Auto steps

Get, put, and list objects in AWS S3 or S3-compatible stores. Part of **coreauto-scripts-pub**.

## Prerequisites

- R 4.0+
- `install.packages("aws.s3")`
- Standard AWS credentials in the environment

## Environment variables

| Variable | Description |
|----------|-------------|
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | Credentials (or `AWS_PROFILE`) |
| `AWS_REGION` | Region (default `us-east-1`) |
| `S3_BUCKET` | Default bucket |
| `S3_ENDPOINT_URL` | Custom endpoint for MinIO / compatible APIs |

## Usage

```r
source("s3client.R")

Init()
PutObject("reports/summary.json", '{"ok":true}')
GetObject("reports/summary.json")
ListObjects("reports/")
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
