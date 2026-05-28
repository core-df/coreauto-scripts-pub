"""
Copyright Core DF

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

JSON, CSV, and XML transform helpers for Core Auto step scripts.
"""

import csv
import io
import json
from typing import Any, List, Optional
from xml.etree import ElementTree as ET


def JsonParse(text: str) -> dict:
    try:
        return {"status_code": 200, "data": json.loads(text)}
    except json.JSONDecodeError as exc:
        return {"status_code": 400, "error": str(exc)}


def JsonStringify(data: Any, indent: Optional[int] = None) -> dict:
    try:
        return {"status_code": 200, "text": json.dumps(data, indent=indent)}
    except (TypeError, ValueError) as exc:
        return {"status_code": 400, "error": str(exc)}


def CsvToRows(text: str, delimiter: str = ",") -> dict:
    try:
        reader = csv.DictReader(io.StringIO(text), delimiter=delimiter)
        return {"status_code": 200, "rows": list(reader)}
    except csv.Error as exc:
        return {"status_code": 400, "error": str(exc)}


def RowsToCsv(rows: List[dict], delimiter: str = ",") -> dict:
    if not rows:
        return {"status_code": 400, "error": "rows must not be empty"}
    try:
        buf = io.StringIO()
        writer = csv.DictWriter(buf, fieldnames=list(rows[0].keys()), delimiter=delimiter)
        writer.writeheader()
        writer.writerows(rows)
        return {"status_code": 200, "text": buf.getvalue()}
    except (csv.Error, KeyError) as exc:
        return {"status_code": 400, "error": str(exc)}


def XmlToDict(text: str) -> dict:
    try:
        root = ET.fromstring(text)

        def _elem(node: ET.Element) -> Any:
            children = list(node)
            if not children:
                return (node.text or "").strip()
            out: dict = {}
            for child in children:
                val = _elem(child)
                tag = child.tag
                if tag in out:
                    if not isinstance(out[tag], list):
                        out[tag] = [out[tag]]
                    out[tag].append(val)
                else:
                    out[tag] = val
            return out

        return {"status_code": 200, "data": {root.tag: _elem(root)}}
    except ET.ParseError as exc:
        return {"status_code": 400, "error": str(exc)}


def DictToXml(data: dict, root_tag: str = "root") -> dict:
    try:
        root = ET.Element(root_tag)

        def _build(parent: ET.Element, obj: Any, tag: str) -> None:
            if isinstance(obj, dict):
                node = ET.SubElement(parent, tag)
                for k, v in obj.items():
                    _build(node, v, k)
            elif isinstance(obj, list):
                for item in obj:
                    _build(parent, item, tag)
            else:
                node = ET.SubElement(parent, tag)
                node.text = "" if obj is None else str(obj)

        for key, val in data.items():
            _build(root, val, key)
        return {"status_code": 200, "text": ET.tostring(root, encoding="unicode")}
    except (TypeError, ValueError) as exc:
        return {"status_code": 400, "error": str(exc)}
