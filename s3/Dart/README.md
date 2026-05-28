# s3 — Dart S3 object storage helpers for Core Auto steps

Get, put, and list objects in AWS S3 or S3-compatible stores (MinIO, etc.). Part of **coreauto-scripts-pub**.

## Prerequisites

- Dart SDK 3.0+
- `dart pub get` (package:minio)

Set `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`, or configure credentials via your environment.

## Environment variables

| Variable | Description |
|----------|-------------|
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | Credentials (or `AWS_PROFILE` for Init check) |
| `AWS_REGION` | Region (default `us-east-1`) |
| `S3_BUCKET` | Default bucket |
| `S3_ENDPOINT_URL` | Custom endpoint for MinIO (full URL, e.g. `https://play.min.io:9000`) |

## Usage

```dart
import 'package:coreauto_s3/s3client.dart';

S3client.Init();
await S3client.PutObject('reports/summary.json', '{"ok":true}');
final obj = await S3client.GetObject('reports/summary.json');
final keys = await S3client.ListObjects('reports/');
```

Functions return `Future<Map<String, dynamic>>` with `status_code` (`200`, `601`, `0`).

## API

| Function | Description |
|----------|-------------|
| `Init()` | Verify credentials and default bucket |
| `GetObject(key, [bucketName])` | Download object as UTF-8 string |
| `PutObject(key, content, [bucketName])` | Upload text |
| `ListObjects([prefix, bucketName])` | List keys |

See [Python](../Python/README.md) for the full API reference.

## License

Apache License 2.0 — see [LICENSE](../../LICENSE).
