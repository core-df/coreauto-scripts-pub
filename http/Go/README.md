# http — HTTP helpers for Core Auto steps

Generic REST/HTTP calls from step scripts (partner APIs, webhooks, internal services). For the **Core Auto Collector**, use [**cawbs**](../../cawbs/README.md) instead.

## Languages

| Language | Path | Module / import |
|----------|------|-----------------|
| Python | [`Python/`](Python/) | `import httpclient as http` |
| Go | [`Go/`](Go/) | `github.com/core-df/coreauto-scripts-pub/http/Go/httpclient` |

## Prerequisites

- **Go** 1.22 or later
- Standard library only (no third-party dependencies)

## Usage

```go
package main

import (
	"fmt"
	"log"

	"github.com/core-df/coreauto-scripts-pub/http/Go/httpclient"
)

func main() {
	result := httpclient.Get("https://api.example.com/orders/123", map[string]string{
		"Authorization": "Bearer ...",
	}, nil)
	if result.StatusCode != 200 {
		log.Fatal(result.Error)
	}
	fmt.Println(result.Body)

	result = httpclient.Post("https://api.example.com/orders", map[string]any{
		"sku": "A1",
		"qty": 2,
	}, nil, nil)
	if result.StatusCode != 200 {
		log.Fatal(result.Error)
	}
}
```

## Build

```shell
cd http/Go
go build ./...
```

## API

| Function | Description |
|----------|-------------|
| `Get(url, headers, params)` | HTTP GET |
| `Post(url, jsonBody, data, headers)` | HTTP POST |
| `Put(url, jsonBody, headers)` | HTTP PUT |
| `Delete(url, headers)` | HTTP DELETE |

Success: `Result{StatusCode: 200, Body: ...}`. Errors include `Error` field. Transport failures use `StatusCode: 0`.

## License

Apache License 2.0 — see [LICENSE](../../LICENSE).
