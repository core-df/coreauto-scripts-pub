# s3 — Swift S3 object storage helpers for Core Auto steps

Get, put, and list objects in AWS S3 or S3-compatible stores (MinIO, etc.). Part of **coreauto-scripts-pub**.

## Prerequisites

- macOS 12+ (Swift 5.9+)
- [Soto](https://github.com/soto-project/soto) (resolved via Swift Package Manager)
- `swift build` in this directory

Credentials follow the standard AWS SDK chain (`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`, `AWS_PROFILE`, instance role, etc.).

## Environment variables

| Variable | Description |
|----------|-------------|
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | Credentials (or `AWS_PROFILE`) |
| `AWS_REGION` | Region (default `us-east-1`) |
| `S3_BUCKET` | Default bucket |
| `S3_ENDPOINT_URL` | Custom endpoint for MinIO / compatible APIs (full URL, e.g. `https://play.min.io:9000`) |

## Usage

```swift
import S3

S3client.Init()
S3client.PutObject("reports/2024/summary.json", content: #"{"ok":true}"#)
let result = S3client.GetObject("reports/2024/summary.json")
let keys = S3client.ListObjects(prefix: "reports/2024/")
```

Functions return `[String: Any]` with `status_code` (`200`, `601`, `0`).

## API

| Function | Description |
|----------|-------------|
| `Init()` | Verify credentials and default bucket |
| `GetObject(key, bucketName)` | Download object as UTF-8 string |
| `PutObject(key, content, bucketName)` | Upload text |
| `ListObjects(prefix, bucketName)` | List keys |

See [Python](../Python/README.md) for the full API reference.

## License

Apache License 2.0 — see [LICENSE](../../LICENSE).
