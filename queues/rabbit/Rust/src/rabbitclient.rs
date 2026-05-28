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
use lapin::options::{
    BasicAckOptions, BasicGetOptions, BasicPublishOptions, QueueDeclareOptions,
};
use lapin::types::FieldTable;
use lapin::{BasicProperties, Connection, ConnectionProperties};
use serde_json::{json, Value};
use std::env;
use std::time::Duration;
use tokio::time::sleep;

fn connection_url() -> String {
    if let Ok(url) = env::var("RABBITMQ_URL") {
        if !url.is_empty() {
            return url;
        }
    }
    let host = env::var("RABBITMQ_HOST").unwrap_or_default();
    if host.is_empty() {
        return String::new();
    }
    let user = urlencoding::encode(&env::var("RABBITMQ_USER").unwrap_or_else(|_| "guest".into()));
    let pass =
        urlencoding::encode(&env::var("RABBITMQ_PASSWORD").unwrap_or_else(|_| "guest".into()));
    let port = env::var("RABBITMQ_PORT").unwrap_or_else(|_| "5672".into());
    let vhost = urlencoding::encode(&env::var("RABBITMQ_VHOST").unwrap_or_else(|_| "/".into()));
    format!("amqp://{user}:{pass}@{host}:{port}/{vhost}")
}

fn encode(value: &Value) -> String {
    match value {
        Value::String(s) => s.clone(),
        other => other.to_string(),
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
    if connection_url().is_empty() {
        return missing_env("RABBITMQ_URL or RABBITMQ_HOST");
    }
    json!({"status_code":200})
}

pub fn publish(queue: &str, value: Value, durable: bool) -> Value {
    let url = connection_url();
    if url.is_empty() {
        return missing_env("RABBITMQ_URL or RABBITMQ_HOST");
    }
    let payload = encode(&value);
    let queue = queue.to_string();
    block_on(async move {
        let conn = match Connection::connect(&url, ConnectionProperties::default()).await {
            Ok(c) => c,
            Err(e) => return transport_error(&e.to_string()),
        };
        let channel = match conn.create_channel().await {
            Ok(ch) => ch,
            Err(e) => return transport_error(&e.to_string()),
        };
        if let Err(e) = channel
            .queue_declare(
                &queue,
                QueueDeclareOptions {
                    durable,
                    ..Default::default()
                },
                FieldTable::default(),
            )
            .await
        {
            return transport_error(&e.to_string());
        }
        if let Err(e) = channel
            .basic_publish(
                "",
                &queue,
                BasicPublishOptions::default(),
                payload.as_bytes(),
                BasicProperties::default(),
            )
            .await
        {
            return transport_error(&e.to_string());
        }
        json!({"status_code":200})
    })
}

pub fn consume(
    queue: &str,
    timeout_sec: f64,
    max_messages: usize,
    auto_ack: bool,
    durable: bool,
) -> Value {
    let url = connection_url();
    if url.is_empty() {
        return missing_env("RABBITMQ_URL or RABBITMQ_HOST");
    }
    let queue = queue.to_string();
    block_on(async move {
        let conn = match Connection::connect(&url, ConnectionProperties::default()).await {
            Ok(c) => c,
            Err(e) => return transport_error(&e.to_string()),
        };
        let channel = match conn.create_channel().await {
            Ok(ch) => ch,
            Err(e) => return transport_error(&e.to_string()),
        };
        if let Err(e) = channel
            .queue_declare(
                &queue,
                QueueDeclareOptions {
                    durable,
                    ..Default::default()
                },
                FieldTable::default(),
            )
            .await
        {
            return transport_error(&e.to_string());
        }
        let mut messages = Vec::new();
        let mut deadline = timeout_sec;
        while messages.len() < max_messages && deadline > 0.0 {
            match channel
                .basic_get(
                    &queue,
                    BasicGetOptions {
                        no_ack: auto_ack,
                        ..Default::default()
                    },
                )
                .await
            {
                Ok(Some(delivery)) => {
                    let tag = delivery.delivery.delivery_tag;
                    let body = decode(&delivery.delivery.data);
                    messages.push(json!({
                        "queue": queue,
                        "delivery_tag": tag,
                        "value": body
                    }));
                    if auto_ack {
                        let _ = delivery
                            .acker
                            .ack(BasicAckOptions::default())
                            .await;
                    }
                }
                Ok(None) => {
                    sleep(Duration::from_secs(1)).await;
                    deadline -= 1.0;
                }
                Err(e) => return transport_error(&e.to_string()),
            }
        }
        json!({"status_code":200,"messages":messages})
    })
}
