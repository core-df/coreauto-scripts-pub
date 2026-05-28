# pubsub — Node.js queue client for Core Auto

**Publish** from step scripts; **Pull** for [ingress](../ingress/Node/README.md) bridges only.

## Prerequisites

- Node.js 18+
- `npm install` (@google-cloud/pubsub)

## Usage

```javascript
import { Publish, Pull } from './pubsubclient.js';
await Publish(...);
const consumed = await Pull(...);
```

## License

Apache License 2.0 — see [LICENSE](../../../LICENSE).
