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

use quick_xml::events::Event;
use quick_xml::reader::Reader;
use quick_xml::Writer;
use serde_json::{json, Map, Value};
use std::io::Cursor;

pub fn json_parse(text: &str) -> Value {
    match serde_json::from_str::<Value>(text) {
        Ok(data) => json!({ "status_code": 200, "data": data }),
        Err(e) => json!({ "status_code": 400, "error": e.to_string() }),
    }
}

pub fn json_stringify(data: &Value, indent: Option<usize>) -> Value {
    let res = if let Some(n) = indent {
        serde_json::to_string_pretty(data)
    } else {
        serde_json::to_string(data)
    };
    match res {
        Ok(text) => json!({ "status_code": 200, "text": text }),
        Err(e) => json!({ "status_code": 400, "error": e.to_string() }),
    }
}

fn split_csv_line(line: &str, delimiter: char) -> Vec<String> {
    let mut fields = Vec::new();
    let mut cur = String::new();
    let mut in_quotes = false;
    for ch in line.chars() {
        match ch {
            '"' if !in_quotes => in_quotes = true,
            '"' if in_quotes => in_quotes = false,
            c if c == delimiter && !in_quotes => {
                fields.push(cur.clone());
                cur.clear();
            }
            c => cur.push(c),
        }
    }
    fields.push(cur);
    fields
}

pub fn csv_to_rows(text: &str, delimiter: &str) -> Value {
    let delim = delimiter.chars().next().unwrap_or(',');
    let mut lines = text.lines();
    let header = match lines.next() {
        Some(h) => h,
        None => return json!({ "status_code": 400, "error": "empty csv" }),
    };
    let cols: Vec<String> = split_csv_line(header, delim);
    let mut rows = Vec::new();
    for line in lines {
        if line.trim().is_empty() {
            continue;
        }
        let vals = split_csv_line(line, delim);
        let mut row = Map::new();
        for (i, col) in cols.iter().enumerate() {
            let v = vals.get(i).cloned().unwrap_or_default();
            row.insert(col.clone(), Value::String(v));
        }
        rows.push(Value::Object(row));
    }
    json!({ "status_code": 200, "rows": rows })
}

pub fn rows_to_csv(rows: &[Map<String, Value>], delimiter: &str) -> Value {
    if rows.is_empty() {
        return json!({ "status_code": 400, "error": "rows must not be empty" });
    }
    let delim = delimiter.chars().next().unwrap_or(',');
    let cols: Vec<String> = rows[0].keys().cloned().collect();
    let mut out = cols.join(&delim.to_string());
    out.push('\n');
    for row in rows {
        let parts: Vec<String> = cols
            .iter()
            .map(|c| row.get(c).map(value_to_string).unwrap_or_default())
            .collect();
        out.push_str(&parts.join(&delim.to_string()));
        out.push('\n');
    }
    json!({ "status_code": 200, "text": out })
}

fn value_to_string(v: &Value) -> String {
    match v {
        Value::String(s) => s.clone(),
        Value::Null => String::new(),
        other => other.to_string(),
    }
}

fn xml_elem_to_value(reader: &mut Reader<Cursor<&[u8]>>, name: &[u8]) -> Result<Value, String> {
    let mut children: Map<String, Value> = Map::new();
    let mut text = String::new();
    loop {
        match reader.read_event().map_err(|e| e.to_string())? {
            Event::Start(e) => {
                let tag = String::from_utf8_lossy(e.name().as_ref()).to_string();
                let val = xml_elem_to_value(reader, e.name().as_ref())?;
                merge_child(&mut children, tag, val);
            }
            Event::Text(t) => {
                text.push_str(&String::from_utf8_lossy(&t.into_inner()));
            }
            Event::End(e) if e.name().as_ref() == name => {
                if children.is_empty() {
                    return Ok(Value::String(text.trim().to_string()));
                }
                return Ok(Value::Object(children));
            }
            Event::Eof => return Err("unexpected eof".into()),
            _ => {}
        }
    }
}

fn merge_child(map: &mut Map<String, Value>, tag: String, val: Value) {
    if let Some(existing) = map.remove(&tag) {
        let arr = match existing {
            Value::Array(mut a) => {
                a.push(val);
                a
            }
            other => vec![other, val],
        };
        map.insert(tag, Value::Array(arr));
    } else {
        map.insert(tag, val);
    }
}

pub fn xml_to_dict(text: &str) -> Value {
    let mut reader = Reader::from_str(text);
    reader.config_mut().trim_text(true);
    loop {
        match reader.read_event() {
            Ok(Event::Start(e)) => {
                let tag = String::from_utf8_lossy(e.name().as_ref()).to_string();
                match xml_elem_to_value(&mut reader, e.name().as_ref()) {
                    Ok(inner) => {
                        let mut data = Map::new();
                        data.insert(tag, inner);
                        return json!({ "status_code": 200, "data": Value::Object(data) });
                    }
                    Err(e) => return json!({ "status_code": 400, "error": e }),
                }
            }
            Ok(Event::Eof) => break,
            Err(e) => return json!({ "status_code": 400, "error": e.to_string() }),
            _ => {}
        }
    }
    json!({ "status_code": 400, "error": "empty xml" })
}

fn write_xml_value(writer: &mut Writer<Cursor<Vec<u8>>>, tag: &str, val: &Value) -> Result<(), String> {
    match val {
        Value::Object(map) => {
            writer
                .create_element(tag)
                .with_attributes([])
                .write_inner_content(|w| {
                    for (k, v) in map {
                        write_xml_value(w, k, v)?;
                    }
                    Ok(())
                })
                .map_err(|e| e.to_string())?;
        }
        Value::Array(arr) => {
            for item in arr {
                write_xml_value(writer, tag, item)?;
            }
        }
        other => {
            let text = value_to_string(other);
            writer
                .create_element(tag)
                .with_text(text.as_bytes())
                .map_err(|e| e.to_string())?;
        }
    }
    Ok(())
}

pub fn dict_to_xml(data: &Map<String, Value>, root_tag: &str) -> Value {
    let mut writer = Writer::new(Cursor::new(Vec::new()));
    if let Err(e) = writer
        .create_element(root_tag)
        .write_inner_content(|w| {
            for (k, v) in data {
                write_xml_value(w, k, v)?;
            }
            Ok(())
        })
    {
        return json!({ "status_code": 400, "error": e.to_string() });
    }
    let buf = writer.into_inner().into_inner();
    match String::from_utf8(buf) {
        Ok(text) => json!({ "status_code": 200, "text": text }),
        Err(e) => json!({ "status_code": 400, "error": e.to_string() }),
    }
}
