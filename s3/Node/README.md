# S3 object storage — Node.js client for Core Auto

Part of **coreauto-scripts-pub**.

## Prerequisites

- Node.js 18+
- `npm install` (@aws-sdk/client-s3)

## Usage

```javascript
import { Init, GetObject, PutObject, ListObjects } from './s3client.js';

const result = await GetObject('reports/daily.csv');
if (result.status_code !== 200) throw new Error(JSON.stringify(result));
```

Functions are **async** and return plain objects with `status_code`. Status codes: `200`, `400`, `601`, `0`.

## License

Apache License 2.0 — see [LICENSE](../../LICENSE).
