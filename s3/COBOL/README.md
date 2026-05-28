# s3 — COBOL

GnuCOBOL bridge to the [C s3 client](../C/README.md) (AWS CLI backend).

## Build

```shell
cd s3/COBOL
make
```

## Entry points

| Entry | Description |
|-------|-------------|
| `S3INIT` | Validate AWS/S3 env |
| `S3GETOBJECT` | Download object |
| `S3PUTOBJECT` | Upload object |
| `S3LISTOBJECTS` | List keys (JSON in buffer) |

Apache License 2.0.
