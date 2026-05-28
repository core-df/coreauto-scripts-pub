# nats — Node.js queue client for Core Auto

**Publish** from step scripts; **Subscribe** for [ingress](../ingress/Node/README.md) bridges only.

## Prerequisites

- Node.js 18+
- `npm install` (nats)

## Usage

```javascript
import { Publish, Subscribe } from './natsclient.js';
await Publish(...);
const consumed = await Subscribe(...);
```

## License

Apache License 2.0 — see [LICENSE](../../../LICENSE).
