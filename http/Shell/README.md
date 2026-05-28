# http — Shell HTTP helpers for Core Auto steps

Generic REST/HTTP calls from step scripts. For the **Core Auto Collector**, use [**cawbs**](../../cawbs/README.md) instead.

## Prerequisites

- bash, curl, jq

## Usage

```bash
source /path/to/http/Shell/httpclient.sh

Get "https://api.example.com/orders/123" '{"Authorization":"Bearer ..."}'
if [[ "$HTTP_STATUS_CODE" != "200" ]]; then echo "$HTTP_RESULT" >&2; exit 1; fi
echo "$HTTP_BODY" | jq .
```

## API

| Function | Description |
|----------|-------------|
| `Get(url, [headers_json])` | HTTP GET |
| `Post(url, json_body, [data], [headers_json])` | HTTP POST |
| `Put(url, json_body, [headers_json])` | HTTP PUT |
| `Delete(url, [headers_json])` | HTTP DELETE |

Each function sets **`HTTP_STATUS_CODE`**, **`HTTP_BODY`**, and **`HTTP_RESULT`** (JSON).

## Status codes

| Code | Meaning |
|------|---------|
| `200` | Success |
| `4xx`/`5xx` | HTTP error (`error` field) |
| `0` | Transport failure (`curl` could not complete) |

## License

Apache License 2.0 — see [LICENSE](../../LICENSE).
