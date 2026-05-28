# S3 object storage — Shell client for Core Auto

Part of **coreauto-scripts-pub**.

## Prerequisites

- bash, jq, AWS CLI (`aws`)

## Usage

```bash
source /path/to/s3/Shell/s3client.sh
GetObject ...
if [[ "${STATUS_VAR}" != "200" ]]; then echo "${RESULT_VAR}" >&2; exit 1; fi
```

Functions set **`S3_RESULT`** (JSON) and **`S3_STATUS_CODE`**. Status codes: `200` success, `400` validation, `601` missing env, `0` transport error.

## License

Apache License 2.0 — see [LICENSE](../../LICENSE).
