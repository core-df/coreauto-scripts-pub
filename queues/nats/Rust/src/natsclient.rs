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
use futures::StreamExt;
use serde_json::{json, Value};
use std::env;
use std::time::Duration;
use tokio::time::timeout;

fn servers() -> String {
    env::var("NATS_URL")
        .or_else(|_| env::var("NATS_SERVERS"))
        .unwrap_or_default()
}

fn encode(value: &Value) -> Vec<u8> {
    match value {
        Value::String(s) => s.as_bytes().to_vec(),
        other => other.to_string().into_bytes(),
    }
}

fn decode(raw: &[u8]) -> Value {
    let s = String::from_utf8_lossy(raw);
    serde_json::from_str(&s).unwrap_or(Value::String(s.to_string()))
}

fn block_on<F: std::future::Future<Output = Value>>(f: F) -> Value {
    match tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
    {
        Ok(rt) => rt.block_on(f),
        Err(e) => transport_error(&e.to_string()),
    }
}

pub fn init() -> Value {
    if servers().is_empty() {
        return missing_env("NATS_URL or NATS_SERVERS");
    }
    json!({"status_code":200})
}

pub fn publish(subject: &str, value: Value) -> Value {
    if servers().is_empty() {
        return missing_env("NATS_URL or NATS_SERVERS");
    }
    let payload = encode(&value);
    let subject = subject.to_string();
    let servers = servers();
    block_on(async move {
        let client = match async_nats::connect(servers).await {
            Ok(c) => c,
            Err(e) => return transport_error(&e.to_string()),
        };
        if let Err(e) = client.publish(subject, payload.into()).await {
            return transport_error(&e.to_string());
        }
        if let Err(e) = client.flush().await {
            return transport_error(&e.to_string());
        }
        json!({"status_code":200})
    })
}

pub fn subscribe(subject: &str, timeout_sec: f64, max_messages: usize) -> Value {
    if servers().is_empty() {
        return missing_env("NATS_URL or NATS_SERVERS");
    }
    let subject = subject.to_string();
    let servers = servers();
    block_on(async move {
        let client = match async_nats::connect(servers).await {
            Ok(c) => c,
            Err(e) => return transport_error(&e.to_string()),
        };
        let mut sub = match client.subscribe(subject.clone()).await {
            Ok(s) => s,
            Err(e) => return transport_error(&e.to_string()),
        };
        let mut messages = Vec::new();
        let mut deadline = timeout_sec;
        while messages.len() < max_messages && deadline > 0.0 {
            let wait = deadline.min(1.0);
            match timeout(Duration::from_secs_f64(wait), sub.next()).await {
                Ok(Some(msg)) => {
                    messages.push(json!({
                        "subject": msg.subject,
                        "value": decode(&msg.payload)
                    }));
                    deadline -= wait;
                }
                Ok(None) => break,
                Err(_) => deadline -= wait,
            }
        }
        json!({"status_code":200,"messages":messages})
    })
}
