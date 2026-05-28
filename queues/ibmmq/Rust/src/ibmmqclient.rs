// Copyright Core DF — Apache License 2.0

use crate::result::{missing_env, transport_error};
use base64::{engine::general_purpose::STANDARD as B64, Engine};
use serde_json::{json, Value};
use std::env;

fn queue_name(explicit: Option<&str>) -> String {
    explicit
        .filter(|s| !s.is_empty())
        .map(str::to_string)
        .or_else(|| env::var("MQ_QUEUE").ok())
        .unwrap_or_default()
}

fn base_url() -> String {
    if let Ok(v) = env::var("MQ_REST_BASE_URL") {
        if !v.is_empty() {
            return v.trim_end_matches('/').to_string();
        }
    }
    let host = env::var("MQ_HOST").unwrap_or_default();
    let port = env::var("MQ_REST_PORT").unwrap_or_else(|_| "9443".into());
    format!("https://{host}:{port}/ibmmq/rest/v2")
}

fn auth_header() -> Option<String> {
    let user = env::var("MQ_USER").unwrap_or_default();
    let password = env::var("MQ_PASSWORD").unwrap_or_default();
    if user.is_empty() {
        return None;
    }
    Some(format!("Basic {}", B64.encode(format!("{user}:{password}"))))
}

pub fn init() -> Value {
    if env::var("MQ_HOST").unwrap_or_default().is_empty() || env::var("MQ_QUEUE_MANAGER").unwrap_or_default().is_empty() {
        return missing_env("MQ_HOST and MQ_QUEUE_MANAGER");
    }
    if env::var("MQ_QUEUE").unwrap_or_default().is_empty() {
        return missing_env("MQ_QUEUE (or pass queue per call)");
    }
    json!({"status_code":200})
}

pub fn put(value: Value, queue: Option<&str>) -> Value {
    let qname = queue_name(queue);
    if qname.is_empty() {
        return missing_env("MQ_QUEUE");
    }
    let qmgr = env::var("MQ_QUEUE_MANAGER").unwrap_or_default();
    let body_str = if value.is_string() {
        value.as_str().unwrap_or("").to_string()
    } else {
        value.to_string()
    };
    let url = format!("{}/messaging/qmgr/{qmgr}/queue/{qname}/message", base_url());
    let payload = json!({"type":"string","content": body_str});
    let mut req = ureq::post(&url).set("Content-Type", "application/json");
    if let Some(auth) = auth_header() {
        req = req.set("Authorization", &auth);
    }
    match req.send_json(payload) {
        Ok(resp) if resp.status() >= 400 => json!({"status_code": resp.status(), "error": resp.into_string().unwrap_or_default()}),
        Ok(_) => json!({"status_code":200}),
        Err(ureq::Error::Status(code, resp)) => json!({"status_code":code,"error":resp.into_string().unwrap_or_default()}),
        Err(e) => transport_error(&e.to_string()),
    }
}

pub fn get(queue: Option<&str>, _timeout_sec: f64, max_messages: usize) -> Value {
    let qname = queue_name(queue);
    if qname.is_empty() {
        return missing_env("MQ_QUEUE");
    }
    let qmgr = env::var("MQ_QUEUE_MANAGER").unwrap_or_default();
    let mut messages = Vec::new();
    for _ in 0..max_messages.max(1) {
        let url = format!("{}/messaging/qmgr/{qmgr}/queue/{qname}/message", base_url());
        let mut req = ureq::delete(&url);
        if let Some(auth) = auth_header() {
            req = req.set("Authorization", &auth);
        }
        let resp = match req.call() {
            Ok(r) => r,
            Err(ureq::Error::Status(204, _)) => break,
            Err(e) => return transport_error(&e.to_string()),
        };
        if resp.status() >= 400 {
            return json!({"status_code": resp.status(), "error": resp.into_string().unwrap_or_default()});
        }
        let text = resp.into_string().unwrap_or_default();
        let parsed: Value = serde_json::from_str(&text).unwrap_or(Value::String(text));
        let content = parsed.get("content").cloned().unwrap_or(parsed);
        let value = if content.is_string() {
            serde_json::from_str(content.as_str().unwrap_or("")).unwrap_or(content)
        } else {
            content
        };
        messages.push(json!({"queue": qname, "value": value}));
    }
    json!({"status_code":200,"messages":messages})
}
