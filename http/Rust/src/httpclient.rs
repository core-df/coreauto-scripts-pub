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

use crate::result::transport_error;
use serde_json::{json, Value};
use std::collections::HashMap;

fn parse_body(text: &str) -> Value {
    if text.is_empty() {
        return Value::Null;
    }
    serde_json::from_str(text).unwrap_or_else(|_| Value::String(text.to_string()))
}

fn apply_headers(req: ureq::Request, headers: &HashMap<String, String>) -> ureq::Request {
    let mut r = req;
    for (k, v) in headers {
        r = r.set(k, v);
    }
    r
}

fn request(
    method: &str,
    url: &str,
    headers: Option<HashMap<String, String>>,
    body: Option<&str>,
    query: Option<HashMap<String, String>>,
) -> Value {
    let mut url = url.to_string();
    if let Some(params) = query {
        if !params.is_empty() {
            let qs: Vec<String> = params
                .iter()
                .map(|(k, v)| format!("{}={}", urlencoding_simple(k), urlencoding_simple(v)))
                .collect();
            let sep = if url.contains('?') { '&' } else { '?' };
            url = format!("{url}{sep}{}", qs.join("&"));
        }
    }

    let hdrs = headers.unwrap_or_default();
    let resp = (|| -> Result<(u16, String), String> {
        let base = match method {
            "GET" => ureq::get(&url),
            "POST" => ureq::post(&url),
            "PUT" => ureq::put(&url),
            "DELETE" => ureq::delete(&url),
            _ => return Err("unsupported method".into()),
        };
        let req = apply_headers(base, &hdrs);
        let resp = if let Some(b) = body {
            req.send_string(b).map_err(|e| e.to_string())?
        } else {
            req.call().map_err(|e| e.to_string())?
        };
        let code = resp.status();
        let text = resp.into_string().map_err(|e| e.to_string())?;
        Ok((code, text))
    })();

    let (code, text) = match resp {
        Ok(v) => v,
        Err(e) => return transport_error(&e),
    };

    let body_val = parse_body(&text);
    if code >= 400 {
        return json!({
            "status_code": code,
            "error": if body_val.is_null() { Value::String("inaccessible".into()) } else { body_val }
        });
    }
    json!({ "status_code": code, "body": body_val })
}

fn urlencoding_simple(s: &str) -> String {
    s.chars()
        .map(|c| match c {
            'A'..='Z' | 'a'..='z' | '0'..='9' | '-' | '_' | '.' | '~' => c.to_string(),
            _ => format!("%{:02X}", c as u32),
        })
        .collect::<String>()
}

pub fn get(
    url: &str,
    headers: Option<HashMap<String, String>>,
    params: Option<HashMap<String, String>>,
) -> Value {
    request("GET", url, headers, None, params)
}

pub fn post(
    url: &str,
    json_body: Option<Value>,
    data: Option<String>,
    headers: Option<HashMap<String, String>>,
) -> Value {
    let mut hdrs = headers.unwrap_or_default();
    let body = if let Some(j) = json_body {
        if !hdrs.contains_key("Content-Type") {
            hdrs.insert("Content-Type".to_string(), "application/json".to_string());
        }
        Some(serde_json::to_string(&j).unwrap_or_default())
    } else {
        data
    };
    request("POST", url, Some(hdrs), body.as_deref(), None)
}

pub fn put(
    url: &str,
    json_body: Option<Value>,
    headers: Option<HashMap<String, String>>,
) -> Value {
    let mut hdrs = headers.unwrap_or_default();
    let body = if let Some(j) = json_body {
        if !hdrs.contains_key("Content-Type") {
            hdrs.insert("Content-Type".to_string(), "application/json".to_string());
        }
        Some(serde_json::to_string(&j).unwrap_or_default())
    } else {
        None
    };
    request("PUT", url, Some(hdrs), body.as_deref(), None)
}

pub fn delete(url: &str, headers: Option<HashMap<String, String>>) -> Value {
    request("DELETE", url, headers, None, None)
}
