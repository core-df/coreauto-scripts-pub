# s3 — C

Uses **AWS CLI** (`aws` on PATH). See [Python](../Python/README.md) for API reference.

## Build

```shell
cd s3/C
make
```

## Functions

| Function | Description |
|----------|-------------|
| `s3_init` | Validate env |
| `s3_get_object` | Download object |
| `s3_put_object` | Upload object |
| `s3_list_objects` | List keys |

## Tests

```shell
cd s3/C
make test
```

Unit tests cover `s3_init` and missing-bucket paths only (no AWS CLI calls).

Apache License 2.0.
