use serde_json::{json, Value};
pub fn missing_env(vars: &str) -> Value { json!({"status_code":601,"error":format!("Environment variables {vars} should be defined")}) }
pub fn transport_error(msg: &str) -> Value { json!({"status_code":0,"error":msg}) }
