# transform — C

Static library `libcoreauto_transform.a` — **libcjson** only (uses shared result helpers from [http/C](../../http/C/include/coreauto_result.h)).

## Build

```shell
cd transform/C
make
make test
```

## API

| Function | Description |
|----------|-------------|
| `transform_json_parse` | Parse JSON text |
| `transform_json_stringify` | Object → JSON text |
| `transform_csv_to_rows` | CSV → row array |
| `transform_rows_to_csv` | Rows → CSV |
| `transform_xml_to_dict` | Simple XML → object |
| `transform_dict_to_xml` | Object → XML stub |

See [Python README](../Python/README.md) for behavior details.

## Tests

Pure logic; no network.

Apache License 2.0.
