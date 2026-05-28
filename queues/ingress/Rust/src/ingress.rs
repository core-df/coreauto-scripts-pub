// Copyright Core DF — Apache License 2.0
//
// Queue ingress bridge — consume from a queue and submit Core Auto events via cawbsingress.

use crate::result::missing_env;
use cawbs::CawbsIngress;
use serde_json::{json, Value};
use std::env;

pub fn trigger_event(payload: Value, event_name: Option<&str>, event_source: Option<&str>) -> Value {
    let name = event_name
        .filter(|s| !s.is_empty())
        .map(str::to_string)
        .or_else(|| env::var("CA_EVENT_NAME").ok())
        .filter(|s| !s.is_empty());
    let Some(name) = name else {
        return missing_env("CA_EVENT_NAME (or pass event_name)");
    };

    let source = event_source
        .map(str::to_string)
        .or_else(|| env::var("CA_EVENT_SOURCE").ok())
        .filter(|s| !s.is_empty());

    let init = CawbsIngress::init();
    if init.status_code >= 400 {
        return json!({
            "status_code": init.status_code,
            "error": init.error
        });
    }

    let post = CawbsIngress::post_event(&name, payload, source.as_deref());
    json!({
        "status_code": post.status_code,
        "error": post.error,
        "actionId": post.action_id,
        "eventId": post.event_id,
    })
}

pub fn forward_messages(consume_result: Value) -> Value {
    if consume_result.get("status_code").and_then(|v| v.as_i64()) != Some(200) {
        return consume_result;
    }
    let mut forwarded = Vec::new();
    if let Some(messages) = consume_result.get("messages").and_then(|v| v.as_array()) {
        for msg in messages {
            let value = msg.get("value").cloned().unwrap_or_else(|| msg.clone());
            let result = trigger_event(value, None, None);
            if result.get("status_code").and_then(|v| v.as_i64()).unwrap_or(0) >= 400 {
                return result;
            }
            forwarded.push(json!({
                "actionId": result.get("actionId").cloned(),
                "eventId": result.get("eventId").cloned(),
            }));
        }
    }
    json!({ "status_code": 200, "forwarded": forwarded })
}

pub fn run_bridge(consume: impl FnOnce() -> Value) -> Value {
    forward_messages(consume())
}
