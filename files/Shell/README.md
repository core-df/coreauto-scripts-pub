# File and SFTP helpers — Shell client for Core Auto

Part of **coreauto-scripts-pub**.

## Prerequisites

- bash, jq, python3, sftp

## Usage

```bash
source /path/to/files/Shell/fileclient.sh
LocalRead ...
if [[ "${STATUS_VAR}" != "200" ]]; then echo "${RESULT_VAR}" >&2; exit 1; fi
```

Functions set **`FILE_RESULT`** (JSON) and **`FILE_STATUS_CODE`**. Status codes: `200` success, `400` validation, `601` missing env, `0` transport error.

## License

Apache License 2.0 — see [LICENSE](../../LICENSE).
