// Copyright Core DF — Apache License 2.0

use crate::result::{missing_env, transport_error};
use base64::{engine::general_purpose::STANDARD as B64, Engine};
use hmac::{Hmac, Mac};
use serde_json::{json, Value};
use sha2::Sha256;
use std::collections::HashMap;
use std::env;
use std::time::{SystemTime, UNIX_EPOCH};

type HmacSha256 = Hmac<Sha256>;

fn connection_string() -> String {
    env::var("SERVICE_BUS_CONNECTION_STRING").unwrap_or_default()
}

fn queue_name(explicit: Option<&str>) -> String {
    explicit
        .filter(|s| !s.is_empty())
        .map(str::to_string)
        .or_else(|| env::var("SERVICE_BUS_QUEUE_NAME").ok())
        .unwrap_or_default()
}

fn parse_conn(conn: &str) -> Option<(String, String, String)> {
    let mut parts = HashMap::new();
    for piece in conn.split(';') {
        if let Some((k, v)) = piece.split_once('=') {
            parts.insert(k.to_string(), v.to_string());
        }
    }
    let endpoint = parts.get("Endpoint")?.replace("sb://", "https://").trim_end_matches('/').to_string();
    Some((endpoint, parts.get("SharedAccessKeyName")?.clone(), parts.get("SharedAccessKey")?.clone()))
}

fn sas_token(resource: &str, key_name: &str, key: &str) -> String {
    let expiry = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs() + 3600)
        .unwrap_or(3600)
        .to_string();
    let encoded = urlencoding::encode(resource);
    let string_to_sign = format!("{encoded}\n{expiry}");
    let mut mac = HmacSha256::new_from_slice(key.as_bytes()).expect("hmac key");
    mac.update(string_to_sign.as_bytes());
    let sig = B64.encode(mac.finalize().into_bytes());
    format!(
        "SharedAccessSignature sr={encoded}&sig={}&se={expiry}&skn={}",
        urlencoding::encode(&sig),
        urlencoding::encode(key_name)
    )
}

pub fn init() -> Value {
    if connection_string().is_empty() {
        return missing_env("SERVICE_BUS_CONNECTION_STRING");
    }
    if env::var("SERVICE_BUS_QUEUE_NAME").unwrap_or_default().is_empty() {
        return missing_env("SERVICE_BUS_QUEUE_NAME (or pass queue per call)");
    }
    json!({"status_code":200})
}

pub fn send(value: Value, queue: Option<&str>) -> Value {
    let conn = connection_string();
    let q = queue_name(queue);
    if conn.is_empty() {
        return missing_env("SERVICE_BUS_CONNECTION_STRING");
    }
    if q.is_empty() {
        return missing_env("SERVICE_BUS_QUEUE_NAME");
    }
    let Some((endpoint, key_name, key)) = parse_conn(&conn) else {
        return transport_error("invalid connection string");
    };
    let resource = format!("{endpoint}/{q}");
    let url = format!("{resource}/messages");
    let body = if value.is_string() {
        value.as_str().unwrap_or("").to_string()
    } else {
        value.to_string()
    };
    let token = sas_token(&resource, &key_name, &key);
    match ureq::post(&url)
        .set("Authorization", &token)
        .set("Content-Type", "application/json")
        .send_string(&body)
    {
        Ok(resp) if resp.status() >= 400 => json!({"status_code": resp.status(), "error": resp.into_string().unwrap_or_default()}),
        Ok(_) => json!({"status_code":200}),
        Err(ureq::Error::Status(code, resp)) => json!({"status_code":code,"error":resp.into_string().unwrap_or_default()}),
        Err(e) => transport_error(&e.to_string()),
    }
}

pub fn receive(queue: Option<&str>, timeout_sec: f64, max_messages: usize, complete: bool) -> Value {
    let conn = connection_string();
    let q = queue_name(queue);
    if conn.is_empty() {
        return missing_env("SERVICE_BUS_CONNECTION_STRING");
    }
    if q.is_empty() {
        return missing_env("SERVICE_BUS_QUEUE_NAME");
    }
    let Some((endpoint, key_name, key)) = parse_conn(&conn) else {
        return transport_error("invalid connection string");
    };
    let resource = format!("{endpoint}/{q}");
    let token = sas_token(&resource, &key_name, &key);
    let mut messages = Vec::new();
    for _ in 0..max_messages.max(1) {
        let url = format!("{resource}/messages/head?timeout={}", timeout_sec as u64);
        let resp = match ureq::post(&url).set("Authorization", &token).call() {
            Ok(r) => r,
            Err(ureq::Error::Status(204, _)) => break,
            Err(e) => return transport_error(&e.to_string()),
        };
        if resp.status() >= 400 {
            return json!({"status_code": resp.status(), "error": resp.into_string().unwrap_or_default()});
        }
        let lock = resp.header("BrokerProperties").and_then(|h| {
            serde_json::from_str::<Value>(h).ok().and_then(|v| v.get("LockToken").and_then(|t| t.as_str()).map(str::to_string))
        });
        let text = resp.into_string().unwrap_or_default();
        let value: Value = serde_json::from_str(&text).unwrap_or(Value::String(text));
        messages.push(json!({"queue": q, "value": value}));
        if complete {
            if let Some(lock_token) = lock {
                let del_url = format!("{resource}/messages/{lock_token}");
                let _ = ureq::delete(&del_url).set("Authorization", &token).call();
            }
        }
    }
    json!({"status_code":200,"messages":messages})
}
