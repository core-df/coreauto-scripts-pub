# transform — Go transform helpers for Core Auto steps

JSON, CSV, and XML transform helpers for step scripts.

## Module

`github.com/core-df/coreauto-scripts-pub/transform/Go`

## Prerequisites

- **Go** 1.22 or later
- Standard library only

## Usage

```go
import "github.com/core-df/coreauto-scripts-pub/transform/Go/transformclient"

result := transformclient.JsonParse(`{"a":1}`)
result = transformclient.CsvToRows("a,b\n1,2", ",")
```

## API

| Function | Description |
|----------|-------------|
| `JsonParse(text)` | Parse JSON string |
| `JsonStringify(data, indent)` | Serialize to JSON |
| `CsvToRows(text, delimiter)` | CSV → row maps |
| `RowsToCsv(rows, delimiter)` | Row maps → CSV |
| `XmlToDict(text)` | XML → nested map |
| `DictToXml(data, rootTag)` | Map → XML |

## License

Apache License 2.0 — see [LICENSE](../../LICENSE).
