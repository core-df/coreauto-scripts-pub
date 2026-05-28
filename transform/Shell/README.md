# Transform helpers — Shell client for Core Auto

Part of **coreauto-scripts-pub**.

## Prerequisites

- bash, jq, python3 (CSV/XML)

## Usage

```bash
source /path/to/transform/Shell/transformclient.sh
JsonParse ...
if [[ "${STATUS_VAR}" != "200" ]]; then echo "${RESULT_VAR}" >&2; exit 1; fi
```

Functions set **`TRANSFORM_RESULT`** (JSON) and **`TRANSFORM_STATUS_CODE`**. Status codes: `200` success, `400` validation, `601` missing env, `0` transport error.

## License

Apache License 2.0 — see [LICENSE](../../LICENSE).
