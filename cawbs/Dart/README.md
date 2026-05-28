# cawbs — Dart client for the Core Auto Collector

Part of **coreauto-scripts-pub**. Not related to **coreauto-mngr-pub**.

## Layout

| Library | Purpose |
|---------|---------|
| **`lib/cawbs.dart`** | Real-time step API |
| **`lib/cawbsbatch.dart`** | Batch: auth + keystore |
| **`lib/wbs.dart`** | Shared HTTP session |

## Prerequisites

- **Dart SDK 3.0+**
- **`http`** package (see `pubspec.yaml`)

## Setup

```shell
cd cawbs/Dart
dart pub get
```

## Usage

```dart
import 'package:cawbs/cawbs.dart' as cawbs;

Future<void> main() async {
  final result = await cawbs.init();
  if (result.statusCode != 200) {
    throw Exception(result.error);
  }
  final event = await cawbs.getEventPayload();
  await cawbs.putStepPayload({'status': 'ok'});
}
```

API methods are **async** (`Future<WbsResult>`).

## Environment variables

Real-time: `ENV`, `ACTIONID`, `CA_ACCESS_CODE`, `CA_WBS_URL`, `STEPNAME`

Batch: `ENV`, `CA_ACCESS_CODE`, `CA_WBS_URL`

## Documentation

- [Core Auto resources](https://coreauto.coredf.com/resources)
