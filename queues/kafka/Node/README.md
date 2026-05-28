# kafka — Node.js queue client for Core Auto

**Produce** from step scripts; **Consume** for [ingress](../ingress/Node/README.md) bridges only.

## Prerequisites

- Node.js 18+
- `npm install` (kafkajs)

## Usage

```javascript
import { Produce, Consume } from './kafkaclient.js';
await Produce(...);
const consumed = await Consume(...);
```

## License

Apache License 2.0 — see [LICENSE](../../../LICENSE).
