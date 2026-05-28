# sqs — Node.js queue client for Core Auto

**Send** from step scripts; **Receive** for [ingress](../ingress/Node/README.md) bridges only.

## Prerequisites

- Node.js 18+
- `npm install` (@aws-sdk/client-sqs)

## Usage

```javascript
import { Send, Receive } from './sqsclient.js';
await Send(...);
const consumed = await Receive(...);
```

## License

Apache License 2.0 — see [LICENSE](../../../LICENSE).
