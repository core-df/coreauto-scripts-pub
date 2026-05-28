# http — Python HTTP helpers for Core Auto steps

Generic REST/HTTP calls from step scripts (partner APIs, webhooks, internal services). For the **Core Auto Collector**, use [**cawbs**](../../cawbs/README.md) instead.

## Prerequisites

- Python 3
- `pip install -r requirements.txt`

## Usage

```python
import httpclient as http

result = http.Get("https://api.example.com/orders/123", headers={"Authorization": "Bearer ..."})
if result["status_code"] != 200:
    raise RuntimeError(result)

result = http.Post("https://api.example.com/orders", json_body={"sku": "A1", "qty": 2})
```

## API

| Function | Description |
|----------|-------------|
| `Get(url, headers=None, params=None)` | HTTP GET |
| `Post(url, json_body=None, data=None, headers=None)` | HTTP POST |
| `Put(url, json_body=None, headers=None)` | HTTP PUT |
| `Delete(url, headers=None)` | HTTP DELETE |

Success: `{"status_code": 200, "body": ...}`. Errors include `error` field.

## License

Apache License 2.0 — see [LICENSE](../../LICENSE).
