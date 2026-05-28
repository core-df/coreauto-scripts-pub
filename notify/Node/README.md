# Notification helpers — Node.js client for Core Auto

Part of **coreauto-scripts-pub**.

## Prerequisites

- Node.js 18+
- `npm install` (nodemailer)

## Usage

```javascript
import { Slack, Teams, Email, PagerDuty } from './notifyclient.js';

const result = await Slack("Job finished OK");
if (result.status_code !== 200) throw new Error(JSON.stringify(result));
```

Functions are **async** and return plain objects with `status_code`. Status codes: `200`, `400`, `601`, `0`.

## License

Apache License 2.0 — see [LICENSE](../../LICENSE).
