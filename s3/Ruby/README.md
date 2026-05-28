# s3 — Ruby S3 object storage helpers for Core Auto steps

Get, put, and list objects in AWS S3 or S3-compatible stores (MinIO, etc.). Part of **coreauto-scripts-pub**.

## Prerequisites

- Ruby 3.0+
- `bundle install` in this directory (`aws-sdk-s3` gem — SigV4 and API calls are not practical with stdlib alone)

## Environment variables

| Variable | Description |
|----------|-------------|
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | Credentials (or `AWS_PROFILE`) |
| `AWS_REGION` | Region (default `us-east-1`) |
| `S3_BUCKET` | Default bucket |
| `S3_ENDPOINT_URL` | Custom endpoint for MinIO / compatible APIs |

## Usage

```ruby
require_relative 'lib/s3client'

S3client.Init
S3client.PutObject('reports/2024/summary.json', '{"ok":true}')
result = S3client.GetObject('reports/2024/summary.json')
keys = S3client.ListObjects('reports/2024/')
```

Methods return hashes with `:status_code` (`200`, `601`, `0`).

## API

| Method | Description |
|--------|-------------|
| `Init` | Verify credentials and default bucket |
| `GetObject(key, bucket_name = nil)` | Download object |
| `PutObject(key, content, bucket_name = nil)` | Upload text |
| `ListObjects(prefix = '', bucket_name = nil)` | List keys |

## License

Apache License 2.0 — see [LICENSE](../../LICENSE).
