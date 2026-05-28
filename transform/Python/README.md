# transform — Python JSON/CSV/XML helpers for Core Auto steps

Parse and serialize payloads between formats in step scripts (stdlib only).

## Prerequisites

- Python 3 (no extra packages)

## Usage

```python
import transformclient as transform

parsed = transform.JsonParse('{"id": 1}')
rows = transform.CsvToRows("a,b\n1,2")
xml = transform.XmlToDict("<order><id>1</id></order>")
```

## API

| Function | Description |
|----------|-------------|
| `JsonParse(text)` | JSON → `data` |
| `JsonStringify(data, indent=None)` | Object → JSON text |
| `CsvToRows(text, delimiter=",")` | CSV → list of dicts |
| `RowsToCsv(rows, delimiter=",")` | Dict rows → CSV text |
| `XmlToDict(text)` | XML → nested dict |
| `DictToXml(data, root_tag="root")` | Dict → XML text |

## License

Apache License 2.0 — see [LICENSE](../../LICENSE).
