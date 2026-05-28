# ibmmq — Node.js queue client for Core Auto

**Put** from step scripts; **Get** for [ingress](../ingress/Node/README.md) bridges only.

## Prerequisites

- Node.js 18+
- `npm install` (ibmmq (optional))

## Usage

```javascript
import { Put, Get } from './ibmmqclient.js';
await Put(...);
const consumed = await Get(...);
```

## License

Apache License 2.0 — see [LICENSE](../../../LICENSE).
