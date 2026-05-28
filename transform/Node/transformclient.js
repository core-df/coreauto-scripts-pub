// Copyright Core DF
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// JSON, CSV, and XML transform helpers for Core Auto step scripts.

import { execFileSync } from 'node:child_process';

function pyXml(script, input, ...args) {
  try {
    const out = execFileSync('python3', ['-c', script, ...args], {
      input,
      encoding: 'utf-8',
    });
    return JSON.parse(out.trim());
  } catch (exc) {
    const msg = exc.stderr?.toString() || exc.message || String(exc);
    return { error: msg };
  }
}

const XML_TO_DICT_PY = `
import json, sys
from xml.etree import ElementTree as ET
text = sys.stdin.read()
root = ET.fromstring(text)
def elem(node):
    children = list(node)
    if not children:
        return (node.text or "").strip()
    out = {}
    for child in children:
        val = elem(child)
        tag = child.tag
        if tag in out:
            if not isinstance(out[tag], list):
                out[tag] = [out[tag]]
            out[tag].append(val)
        else:
            out[tag] = val
    return out
print(json.dumps({"data": {root.tag: elem(root)}}))
`;

const DICT_TO_XML_PY = `
import json, sys
from xml.etree import ElementTree as ET
root_tag = sys.argv[1] if len(sys.argv) > 1 else "root"
data = json.loads(sys.stdin.read())
def build(parent, obj, tag):
    if isinstance(obj, dict):
        node = ET.SubElement(parent, tag)
        for k, v in obj.items():
            build(node, v, k)
    elif isinstance(obj, list):
        for item in obj:
            build(parent, item, tag)
    else:
        node = ET.SubElement(parent, tag)
        node.text = "" if obj is None else str(obj)
root = ET.Element(root_tag)
for key, val in data.items():
    build(root, val, key)
print(json.dumps({"text": ET.tostring(root, encoding="unicode")}))
`;

export function JsonParse(text) {
  try {
    return { status_code: 200, data: JSON.parse(text) };
  } catch (exc) {
    return { status_code: 400, error: String(exc.message) };
  }
}

export function JsonStringify(data, indent = null) {
  try {
    return { status_code: 200, text: JSON.stringify(data, null, indent) };
  } catch (exc) {
    return { status_code: 400, error: String(exc.message) };
  }
}

export function CsvToRows(text, delimiter = ',') {
  try {
    const lines = text.split(/\r?\n/).filter((l) => l.length > 0);
    if (lines.length === 0) {
      return { status_code: 200, rows: [] };
    }
    const headers = lines[0].split(delimiter);
    const rows = lines.slice(1).map((line) => {
      const vals = line.split(delimiter);
      const row = {};
      headers.forEach((h, i) => {
        row[h] = vals[i] ?? '';
      });
      return row;
    });
    return { status_code: 200, rows };
  } catch (exc) {
    return { status_code: 400, error: String(exc.message) };
  }
}

export function RowsToCsv(rows, delimiter = ',') {
  if (!rows || rows.length === 0) {
    return { status_code: 400, error: 'rows must not be empty' };
  }
  try {
    const keys = Object.keys(rows[0]);
    const header = keys.join(delimiter);
    const body = rows.map((r) => keys.map((k) => r[k] ?? '').join(delimiter)).join('\n');
    return { status_code: 200, text: `${header}\n${body}\n` };
  } catch (exc) {
    return { status_code: 400, error: String(exc.message) };
  }
}

export function XmlToDict(text) {
  const result = pyXml(XML_TO_DICT_PY, text);
  if (result.error) return { status_code: 400, error: result.error };
  return { status_code: 200, data: result.data };
}

export function DictToXml(data, rootTag = 'root') {
  const result = pyXml(DICT_TO_XML_PY, JSON.stringify(data), rootTag);
  if (result.error) return { status_code: 400, error: result.error };
  return { status_code: 200, text: result.text };
}
