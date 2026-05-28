// Copyright Core DF — Apache License 2.0

use serde_json::{json, Value};
use std::env;

pub fn missing_env(vars: &str) -> Value {
    json!({
        "status_code": 601,
        "error": format!("Environment variables {vars} should be defined")
    })
}

pub fn transport_error(message: &str) -> Value {
    json!({ "status_code": 0, "error": message })
}
