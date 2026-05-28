# cawbs — PHP client for the Core Auto Collector

Part of **coreauto-scripts-pub**. Not related to **coreauto-mngr-pub**.

## Modules

| File | Use case |
|------|----------|
| **`cawbs.php`** | Real-time steps |
| **`cawbsbatch.php`** | Batch: auth + keystore |

## Prerequisites

- **PHP 8.1+**
- **`curl`** extension enabled

## Usage

```php
<?php
require_once '/path/to/cawbs/PHP/cawbs.php';

$result = Cawbs::Init();
if ($result->status_code !== 200) {
    throw new RuntimeException(json_encode($result->toArray()));
}

$event = Cawbs::GetEventPayload();
Cawbs::PutStepPayload(['status' => 'ok']);
```

## Environment variables

Real-time: `ENV`, `ACTIONID`, `CA_ACCESS_CODE`, `CA_WBS_URL`, `STEPNAME`

Batch: `ENV`, `CA_ACCESS_CODE`, `CA_WBS_URL`

## Documentation

- [Core Auto resources](https://coreauto.coredf.com/resources)
