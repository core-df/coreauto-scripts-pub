# rabbit — Node.js queue client for Core Auto

**Publish** from step scripts; **Consume** for [ingress](../ingress/Node/README.md) bridges only.

## Prerequisites

- Node.js 18+
- `npm install` (amqplib)

## Usage

```javascript
import { Publish, Consume } from './rabbitclient.js';
await Publish(...);
const consumed = await Consume(...);
```

## License

Apache License 2.0 — see [LICENSE](../../../LICENSE).
