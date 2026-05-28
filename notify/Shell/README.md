# Notification helpers — Shell client for Core Auto

Part of **coreauto-scripts-pub**.

## Prerequisites

- bash, curl, jq, python3 (email)

## Usage

```bash
source /path/to/notify/Shell/notifyclient.sh
Slack ...
if [[ "${STATUS_VAR}" != "200" ]]; then echo "${RESULT_VAR}" >&2; exit 1; fi
```

Functions set **`NOTIFY_RESULT`** (JSON) and **`NOTIFY_STATUS_CODE`**. Status codes: `200` success, `400` validation, `601` missing env, `0` transport error.

## License

Apache License 2.0 — see [LICENSE](../../LICENSE).
