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
use aws_sdk_sqs::Client;
use serde_json::{json, Value};
use std::env;

fn region() -> String {
    env::var("AWS_REGION")
        .or_else(|_| env::var("AWS_DEFAULT_REGION"))
        .unwrap_or_else(|_| "us-east-1".into())
}

fn queue_url(explicit: Option<&str>) -> String {
    explicit
        .filter(|s| !s.is_empty())
        .map(str::to_string)
        .or_else(|| env::var("SQS_QUEUE_URL").ok())
        .unwrap_or_default()
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

async fn aws_client() -> Result<Client, String> {
    let shared = aws_config::defaults(aws_config::BehaviorVersion::latest())
        .region(aws_config::Region::new(region()))
        .load()
        .await;
    let mut builder = aws_sdk_sqs::config::Builder::from(&shared);
    if let Ok(endpoint) = env::var("SQS_ENDPOINT_URL") {
        if !endpoint.is_empty() {
            builder = builder.endpoint_url(endpoint);
        }
    }
    Ok(Client::from_conf(builder.build()))
}

fn block_on<F: std::future::Future<Output = Value>>(f: F) -> Value {
    match tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
    {
        Ok(rt) => rt.block_on(f),
        Err(e) => transport_error(&e.to_string()),
    }
}

pub fn init() -> Value {
    if env::var("AWS_ACCESS_KEY_ID").unwrap_or_default().is_empty()
        && env::var("AWS_PROFILE").unwrap_or_default().is_empty()
    {
        return missing_env("AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY or AWS_PROFILE");
    }
    if env::var("SQS_QUEUE_URL").unwrap_or_default().is_empty() {
        return missing_env("SQS_QUEUE_URL (or pass queue_url per call)");
    }
    json!({"status_code":200})
}

pub fn send(value: Value, queue_url_arg: Option<&str>) -> Value {
    let url = queue_url(queue_url_arg);
    if url.is_empty() {
        return missing_env("SQS_QUEUE_URL");
    }
    let body = encode(&value);
    block_on(async move {
        let client = match aws_client().await {
            Ok(c) => c,
            Err(e) => return transport_error(&e),
        };
        match client
            .send_message()
            .queue_url(&url)
            .message_body(body)
            .send()
            .await
        {
            Ok(resp) => json!({
                "status_code": 200,
                "message_id": resp.message_id()
            }),
            Err(e) => transport_error(&e.to_string()),
        }
    })
}

pub fn receive(
    queue_url_arg: Option<&str>,
    max_messages: i32,
    wait_time_sec: i32,
    delete: bool,
) -> Value {
    let url = queue_url(queue_url_arg);
    if url.is_empty() {
        return missing_env("SQS_QUEUE_URL");
    }
    let max_messages = max_messages.clamp(1, 10);
    block_on(async move {
        let client = match aws_client().await {
            Ok(c) => c,
            Err(e) => return transport_error(&e),
        };
        let resp = match client
            .receive_message()
            .queue_url(&url)
            .max_number_of_messages(max_messages)
            .wait_time_seconds(wait_time_sec)
            .send()
            .await
        {
            Ok(r) => r,
            Err(e) => return transport_error(&e.to_string()),
        };
        let mut messages = Vec::new();
        for item in resp.messages() {
            let message_id = item.message_id().unwrap_or_default().to_string();
            let receipt_handle = item.receipt_handle().unwrap_or_default().to_string();
            let body = item.body().unwrap_or_default();
            messages.push(json!({
                "message_id": message_id,
                "receipt_handle": receipt_handle,
                "value": decode(body)
            }));
            if delete && !receipt_handle.is_empty() {
                if let Err(e) = client
                    .delete_message()
                    .queue_url(&url)
                    .receipt_handle(&receipt_handle)
                    .send()
                    .await
                {
                    return transport_error(&e.to_string());
                }
            }
        }
        json!({"status_code":200,"messages":messages})
    })
}
