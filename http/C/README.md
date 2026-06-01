# http — C

Static library `libcoreauto_http.a` — JSON results via **libcurl** and **libcjson**.

## Build

```shell
cd http/C
make
make test
```

## API

| Function | Description |
|----------|-------------|
| `http_get` | HTTP GET |
| `http_post_json` | HTTP POST with JSON body |
| `http_put_json` | HTTP PUT with JSON body |
| `http_delete` | HTTP DELETE |

Returns malloc'd JSON `{status_code, body?, error?}`. Free with `coreauto_json_free()`.

## Tests

Loopback mock server in [`tests/c`](../../tests/c/README.md); no external HTTP required.

## License

Apache License 2.0.
