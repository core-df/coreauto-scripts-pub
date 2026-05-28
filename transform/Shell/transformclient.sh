#!/usr/bin/env bash
# Copyright Core DF
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# JSON, CSV, and XML transform helpers for Core Auto step scripts.

_TRANSFORMCLIENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=lib/result.sh
source "${_TRANSFORMCLIENT_DIR}/lib/result.sh"

JsonParse() {
  local text=$1
  local out err
  if out=$(echo "$text" | jq -c . 2>&1); then
    _transform_set_result 200 "" "{\"data\":${out}}"
  else
    err=$(echo "$out" | head -1)
    _transform_set_result 400 "$err"
  fi
}

JsonStringify() {
  local data=$1 indent=${2:-}
  local out err
  if [[ -n $indent && $indent != "null" ]]; then
    if out=$(echo "$data" | jq --argjson ind "$indent" '.' 2>&1); then
      _transform_set_result 200 "" "$(jq -nc --arg t "$out" '{text: $t}')"
    else
      _transform_set_result 400 "$(echo "$out" | head -1)"
    fi
  else
    if out=$(echo "$data" | jq -c . 2>&1); then
      _transform_set_result 200 "" "$(jq -nc --arg t "$out" '{text: $t}')"
    else
      _transform_set_result 400 "$(echo "$out" | head -1)"
    fi
  fi
}

CsvToRows() {
  local text=$1 delimiter=${2:-,}
  local out
  if ! out=$(python3 - "$delimiter" <<'PY' 2>&1
import csv, io, json, sys
delimiter = sys.argv[1] if len(sys.argv) > 1 else ","
text = sys.stdin.read()
try:
    reader = csv.DictReader(io.StringIO(text), delimiter=delimiter)
    print(json.dumps({"rows": list(reader)}))
except csv.Error as exc:
    print(f"ERROR:{exc}", file=sys.stderr)
    sys.exit(1)
PY
<<< "$text"); then
    _transform_set_result 400 "$(echo "$out" | sed 's/^ERROR://')"
    return 0
  fi
  _transform_set_result 200 "" "$out"
}

RowsToCsv() {
  local rows_json=$1 delimiter=${2:-,}
  local out
  if ! out=$(python3 - "$delimiter" <<'PY' 2>&1
import csv, io, json, sys
delimiter = sys.argv[1] if len(sys.argv) > 1 else ","
rows = json.loads(sys.stdin.read())
if not rows:
    print("ERROR:rows must not be empty", file=sys.stderr)
    sys.exit(1)
try:
    buf = io.StringIO()
    writer = csv.DictWriter(buf, fieldnames=list(rows[0].keys()), delimiter=delimiter)
    writer.writeheader()
    writer.writerows(rows)
    print(json.dumps({"text": buf.getvalue()}))
except (csv.Error, KeyError) as exc:
    print(f"ERROR:{exc}", file=sys.stderr)
    sys.exit(1)
PY
<<< "$rows_json"); then
    local err
    err=$(echo "$out" | sed 's/^ERROR://')
    _transform_set_result 400 "$err"
    return 0
  fi
  _transform_set_result 200 "" "$out"
}

XmlToDict() {
  local text=$1
  local out
  if ! out=$(python3 - <<'PY' 2>&1
import json, sys
from xml.etree import ElementTree as ET

text = sys.stdin.read()
try:
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
except ET.ParseError as exc:
    print(f"ERROR:{exc}", file=sys.stderr)
    sys.exit(1)
PY
<<< "$text"); then
    _transform_set_result 400 "$(echo "$out" | sed 's/^ERROR://')"
    return 0
  fi
  _transform_set_result 200 "" "$out"
}

DictToXml() {
  local data_json=$1 root_tag=${2:-root}
  local out
  if ! out=$(python3 - "$root_tag" <<'PY' 2>&1
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
PY
<<< "$data_json"); then
    _transform_set_result 400 "$(echo "$out" | sed 's/^ERROR://')"
    return 0
  fi
  _transform_set_result 200 "" "$out"
}
