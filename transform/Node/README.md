# Transform helpers — Node.js client for Core Auto

Part of **coreauto-scripts-pub**.

## Prerequisites

- Node.js 18+
- python3 on PATH for XML (optional)

## Usage

```javascript
import { JsonParse, JsonStringify, CsvToRows, RowsToCsv, XmlToDict, DictToXml } from './transformclient.js';

const result = await JsonParse('{"a":1}');
if (result.status_code !== 200) throw new Error(JSON.stringify(result));
```

Functions are **async** and return plain objects with `status_code`. Status codes: `200`, `400`, `601`, `0`.

## License

Apache License 2.0 — see [LICENSE](../../LICENSE).
