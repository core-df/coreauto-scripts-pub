# File and SFTP helpers — Node.js client for Core Auto

Part of **coreauto-scripts-pub**.

## Prerequisites

- Node.js 18+
- `npm install` (optional `ssh2-sftp-client` for SFTP)

## Usage

```javascript
import { LocalRead, LocalWrite, LocalMove, SftpGet, SftpPut, SftpList } from './fileclient.js';

const result = await LocalRead('/path/to/file.txt');
if (result.status_code !== 200) throw new Error(JSON.stringify(result));
```

Functions are **async** and return plain objects with `status_code`. Status codes: `200`, `400`, `601`, `0`.

## License

Apache License 2.0 — see [LICENSE](../../LICENSE).
