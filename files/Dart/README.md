# files — Dart local file helpers for Core Auto steps

Read, write, and move files on the local filesystem. Part of **coreauto-scripts-pub**.

## Prerequisites

- Dart SDK 3.0+
- `dart pub get` in this directory

## Usage

```dart
import 'package:coreauto_files/fileclient.dart';

final read = Fileclient.LocalRead('/data/inbox/order.csv');
Fileclient.LocalWrite('/data/out/ack.json', '{"ok":true}');
Fileclient.LocalMove('/data/inbox/order.csv', '/data/processing/order.csv');
```

Functions return `Map<String, dynamic>` with `status_code`. Local I/O errors use `500`.

## API

| Function | Description |
|----------|-------------|
| `LocalRead(path, {encoding})` | Read text file (UTF-8) |
| `LocalWrite(path, content, {encoding})` | Write text; creates parent directories |
| `LocalMove(src, dest)` | Rename/move file |

## SFTP

SFTP (`SftpGet`, `SftpPut`, `SftpList`) is **not** implemented in this Dart port. Use [Python](../Python/README.md) or [Kotlin](../Kotlin/README.md) for SFTP.

See [Python](../Python/README.md) for the full API reference.

## License

Apache License 2.0 — see [LICENSE](../../LICENSE).
