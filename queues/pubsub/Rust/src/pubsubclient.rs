// Copyright Core DF — Apache License 2.0

use crate::result::{missing_env, transport_error};
use base64::{engine::general_purpose::STANDARD as B64, Engine};
use serde_json::{json, Value};
use std::env;
use std::process::Command;

fn project_id() -> String {
    env::var("PUBSUB_PROJECT_ID")
        .or_else(|_| env::var("GOOGLE_CLOUD_PROJECT"))
        .unwrap_or_default()
}

fn topic_id(explicit: Option<&str>) -> String {
    explicit
        .filter(|s| !s.is_empty())
        .map(str::to_string)
        .or_else(|| env::var("PUBSUB_TOPIC_ID").ok())
        .unwrap_or_default()
}

fn subscription_id(explicit: Option<&str>) -> String {
    explicit
        .filter(|s| !s.is_empty())
        .map(str::to_string)
        .or_else(|| env::var("PUBSUB_SUBSCRIPTION_ID").ok())
        .unwrap_or_default()
}

fn access_token() -> Option<String> {
    if let Ok(t) = env::var("GOOGLE_ACCESS_TOKEN") {
        if !t.is_empty() {
            return Some(t);
        }
    }
    let out = Command::new("gcloud")
        .args(["auth", "application-default", "print-access-token"])
        .output()
        .ok()?;
    if !out.status.success() {
        return None;
    }
    Some(String::from_utf8_lossy(&out.stdout).trim().to_string())
}

pub fn init() -> Value {
    if project_id().is_empty() {
        return missing_env("PUBSUB_PROJECT_ID or GOOGLE_CLOUD_PROJECT");
    }
    json!({"status_code":200})
}

pub fn publish(value: Value, topic: Option<&str>) -> Value {
    let project = project_id();
    let tid = topic_id(topic);
    if project.is_empty() {
        return missing_env("PUBSUB_PROJECT_ID or GOOGLE_CLOUD_PROJECT");
    }
    if tid.is_empty() {
        return missing_env("PUBSUB_TOPIC_ID");
    }
    let Some(token) = access_token() else {
        return json!({"status_code":500,"error":"gcloud auth or GOOGLE_ACCESS_TOKEN required"});
    };
    let data = if value.is_string() {
        value.as_str().unwrap_or("").to_string()
    } else {
        value.to_string()
    };
    let encoded = B64.encode(data.as_bytes());
    let url = format!("https://pubsub.googleapis.com/v1/projects/{project}/topics/{tid}:publish");
    let body = json!({"messages":[{"data": encoded}]});
    match ureq::post(&url)
        .set("Authorization", &format!("Bearer {token}"))
        .set("Content-Type", "application/json")
        .send_json(body)
    {
        Ok(resp) if resp.status() >= 400 => json!({"status_code": resp.status(), "error": resp.into_string().unwrap_or_default()}),
        Ok(resp) => {
            let text = resp.into_string().unwrap_or_default();
            let parsed: Value = serde_json::from_str(&text).unwrap_or(json!({}));
            let msg_id = parsed.pointer("/messageIds/0").cloned();
            json!({"status_code":200,"message_id":msg_id})
        }
        Err(ureq::Error::Status(code, resp)) => json!({"status_code":code,"error":resp.into_string().unwrap_or_default()}),
        Err(e) => transport_error(&e.to_string()),
    }
}

pub fn pull(subscription: Option<&str>, max_messages: usize, _timeout_sec: f64, ack: bool) -> Value {
    let project = project_id();
    let sub_id = subscription_id(subscription);
    if project.is_empty() {
        return missing_env("PUBSUB_PROJECT_ID or GOOGLE_CLOUD_PROJECT");
    }
    if sub_id.is_empty() {
        return missing_env("PUBSUB_SUBSCRIPTION_ID");
    }
    let Some(token) = access_token() else {
        return json!({"status_code":500,"error":"gcloud auth or GOOGLE_ACCESS_TOKEN required"});
    };
    let url = format!("https://pubsub.googleapis.com/v1/projects/{project}/subscriptions/{sub_id}:pull");
    let body = json!({"maxMessages": max_messages.max(1).min(1000)});
    let resp = match ureq::post(&url)
        .set("Authorization", &format!("Bearer {token}"))
        .set("Content-Type", "application/json")
        .send_json(body)
    {
        Ok(r) if r.status() >= 400 => return json!({"status_code": r.status(), "error": r.into_string().unwrap_or_default()}),
        Ok(r) => r,
        Err(e) => return transport_error(&e.to_string()),
    };
    let text = resp.into_string().unwrap_or_default();
    let parsed: Value = serde_json::from_str(&text).unwrap_or(json!({}));
    let mut messages = Vec::new();
    let mut ack_ids = Vec::new();
    if let Some(received) = parsed.get("receivedMessages").and_then(|v| v.as_array()) {
        for item in received {
            let msg_id = item.pointer("/message/messageId").and_then(|v| v.as_str());
            let data_b64 = item.pointer("/message/data").and_then(|v| v.as_str()).unwrap_or("");
            let raw = B64.decode(data_b64).unwrap_or_default();
            let value: Value = serde_json::from_slice(&raw).unwrap_or(Value::String(String::from_utf8_lossy(&raw).into()));
            messages.push(json!({"subscription": sub_id, "message_id": msg_id, "value": value}));
            if let Some(id) = item.get("ackId").and_then(|v| v.as_str()) {
                ack_ids.push(id.to_string());
            }
        }
    }
    if ack && !ack_ids.is_empty() {
        let ack_url = format!("https://pubsub.googleapis.com/v1/projects/{project}/subscriptions/{sub_id}:acknowledge");
        let _ = ureq::post(&ack_url)
            .set("Authorization", &format!("Bearer {token}"))
            .set("Content-Type", "application/json")
            .send_json(json!({"ackIds": ack_ids}));
    }
    json!({"status_code":200,"messages":messages})
}
