# http — Node.js HTTP helpers for Core Auto steps

Generic REST/HTTP calls from step scripts. For the **Core Auto Collector**, use [**cawbs**](../../cawbs/README.md) instead.

## Prerequisites

- Node.js 18+ (native `fetch`)
- No npm dependencies

## Usage

```javascript
import { Get, Post } from './httpclient.js';

const result = await Get('https://api.example.com/orders/123', {
  Authorization: 'Bearer ...',
});
if (result.status_code !== 200) throw new Error(JSON.stringify(result));
```

## API

| Function | Description |
|----------|-------------|
| `Get(url, headers, params)` | HTTP GET |
| `Post(url, jsonBody, data, headers)` | HTTP POST |
| `Put(url, jsonBody, headers)` | HTTP PUT |
| `Delete(url, headers)` | HTTP DELETE |

## Status codes

`200` success, `4xx`/`5xx` HTTP errors, `0` transport failure.

## License

Apache License 2.0 — see [LICENSE](../../LICENSE).
