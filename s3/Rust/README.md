# s3 — Rust S3 object storage helpers for Core Auto steps

Get, put, and list objects in AWS S3 or S3-compatible stores (MinIO, etc.). Part of **coreauto-scripts-pub**.

## Prerequisites

- Rust 1.70+
- `cargo build` (aws-sdk-s3, aws-config, tokio)

Credentials follow the standard AWS SDK chain (`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`, `AWS_PROFILE`, instance role, etc.).

## Environment variables

| Variable | Description |
|----------|-------------|
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | Credentials (or `AWS_PROFILE`) |
| `AWS_REGION` | Region (default `us-east-1`) |
| `S3_BUCKET` | Default bucket |
| `S3_ENDPOINT_URL` | Custom endpoint for MinIO / compatible APIs (path-style) |

## Usage

```rust
use coreauto_s3::{init, get_object, put_object, list_objects};

init();
put_object("reports/2024/summary.json", r#"{"ok":true}"#, None);
let result = get_object("reports/2024/summary.json", None);
let keys = list_objects("reports/2024/", None);
```

Functions return `serde_json::Value` with `status_code` (`200`, `601`, `0`).

## API

| Function | Description |
|----------|-------------|
| `init()` | Verify credentials and default bucket |
| `get_object(key, bucket)` | Download object (UTF-8 string or JSON byte array) |
| `put_object(key, content, bucket)` | Upload text |
| `list_objects(prefix, bucket)` | List keys |

## License

Apache License 2.0 — see [LICENSE](../../LICENSE).
