# ingress — Node.js queue → Core Auto event bridge

## Prerequisites

- Node.js 18+
- [cawbsingress Node](../../../cawbs/Node/cawbsingress.js) (set `CAWBS_NODE` if needed)

## Usage

```javascript
import { Consume } from '../../kafka/Node/kafkaclient.js';
import { RunBridge } from './ingress.js';

await RunBridge(Consume, 'orders', 30, 10);
```

## API

`TriggerEvent`, `ForwardMessages`, `RunBridge(consumeFn, ...args)`

## License

Apache License 2.0 — see [LICENSE](../../../LICENSE).
