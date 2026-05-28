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

use crate::result::{missing_env, transport_error};
use redis::Commands;
use serde_json::{json, Value};
use std::env;

fn connection_url() -> String {
    if let Ok(url) = env::var("REDIS_URL") {
        if !url.is_empty() {
            return url;
        }
    }
    let host = env::var("REDIS_HOST").unwrap_or_default();
    if host.is_empty() {
        return String::new();
    }
    let port = env::var("REDIS_PORT").unwrap_or_else(|_| "6379".into());
    let db = env::var("REDIS_DB").unwrap_or_else(|_| "0".into());
    let pass = env::var("REDIS_PASSWORD").unwrap_or_default();
    if pass.is_empty() {
        format!("redis://{host}:{port}/{db}")
    } else {
        format!(
            "redis://:{}@{}:{}/{}",
            urlencoding::encode(&pass),
            host,
            port,
            db
        )
    }
}

fn encode(value: &Value) -> String {
    match value {
        Value::String(s) => s.clone(),
        other => other.to_string(),
    }
}

fn decode(raw: &str) -> Value {
    serde_json::from_str(raw).unwrap_or(Value::String(raw.to_string()))
}

pub fn init() -> Value {
    if connection_url().is_empty() {
        return missing_env("REDIS_URL or REDIS_HOST");
    }
    json!({"status_code":200})
}

pub fn push(queue: &str, value: Value) -> Value {
    let url = connection_url();
    if url.is_empty() {
        return missing_env("REDIS_URL or REDIS_HOST");
    }
    let payload = encode(&value);
    let client = match redis::Client::open(url.as_str()) {
        Ok(c) => c,
        Err(e) => return transport_error(&e.to_string()),
    };
    let mut con = match client.get_connection() {
        Ok(c) => c,
        Err(e) => return transport_error(&e.to_string()),
    };
    match con.lpush::<_, _, ()>(queue, payload) {
        Ok(()) => json!({"status_code":200}),
        Err(e) => transport_error(&e.to_string()),
    }
}

pub fn pop(queue: &str, timeout_sec: f64, max_messages: usize) -> Value {
    let url = connection_url();
    if url.is_empty() {
        return missing_env("REDIS_URL or REDIS_HOST");
    }
    let client = match redis::Client::open(url.as_str()) {
        Ok(c) => c,
        Err(e) => return transport_error(&e.to_string()),
    };
    let mut con = match client.get_connection() {
        Ok(c) => c,
        Err(e) => return transport_error(&e.to_string()),
    };
    let mut messages = Vec::new();
    let mut remaining = max_messages.max(1);
    let mut deadline = timeout_sec;
    while remaining > 0 {
        let wait = if remaining == max_messages {
            deadline.max(1.0) as f64
        } else {
            1.0
        };
        match con.brpop::<_, Option<(String, String)>>(queue, wait) {
            Ok(Some((_key, body))) => {
                messages.push(json!({"queue": queue, "value": decode(&body)}));
                remaining -= 1;
                deadline -= wait;
                if deadline <= 0.0 {
                    break;
                }
            }
            Ok(None) => break,
            Err(e) => return transport_error(&e.to_string()),
        }
    }
    json!({"status_code":200,"messages":messages})
}
