# redis — Node.js queue client for Core Auto

**Push** from step scripts; **Pop** for [ingress](../ingress/Node/README.md) bridges only.

## Prerequisites

- Node.js 18+
- `npm install` (redis)

## Usage

```javascript
import { Push, Pop } from './redisclient.js';
await Push(...);
const consumed = await Pop(...);
```

## License

Apache License 2.0 — see [LICENSE](../../../LICENSE).
