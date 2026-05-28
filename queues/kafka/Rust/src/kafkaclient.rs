use crate::result::{missing_env, transport_error};
use rdkafka::config::ClientConfig;
use rdkafka::consumer::{Consumer, StreamConsumer};
use rdkafka::message::Message;
use rdkafka::producer::{FutureProducer, FutureRecord};
use serde_json::{json, Value};
use std::env;
use std::time::Duration;

fn bootstrap() -> String { env::var("KAFKA_BOOTSTRAP_SERVERS").unwrap_or_default() }

fn base_config() -> ClientConfig {
    let mut c = ClientConfig::new();
    c.set("bootstrap.servers", &bootstrap());
    for (k, e) in [
        ("security.protocol", "KAFKA_SECURITY_PROTOCOL"),
        ("sasl.mechanism", "KAFKA_SASL_MECHANISM"),
        ("sasl.username", "KAFKA_SASL_USERNAME"),
        ("sasl.password", "KAFKA_SASL_PASSWORD"),
    ] {
        if let Ok(v) = env::var(e) { c.set(k, &v); }
    }
    c
}

pub fn init() -> Value {
    if bootstrap().is_empty() { return missing_env("KAFKA_BOOTSTRAP_SERVERS"); }
    json!({"status_code":200})
}

pub fn produce(topic: &str, value: Value, key: Option<&str>) -> Value {
    if bootstrap().is_empty() { return missing_env("KAFKA_BOOTSTRAP_SERVERS"); }
    let payload = match value {
        Value::String(s) => s,
        other => other.to_string(),
    };
    let producer: FutureProducer = match base_config().create() {
        Ok(p) => p,
        Err(e) => return transport_error(&e.to_string()),
    };
    let mut rec = FutureRecord::to(topic).payload(&payload);
    if let Some(k) = key { rec = rec.key(k); }
    match producer.send(rec, Duration::from_secs(30)) {
        Ok(_) => json!({"status_code":200}),
        Err((e, _)) => json!({"status_code":500,"error":e.to_string()}),
    }
}

pub fn consume(topic: &str, timeout_sec: f64, max_messages: usize, group_id: Option<&str>) -> Value {
    if bootstrap().is_empty() { return missing_env("KAFKA_BOOTSTRAP_SERVERS"); }
    let gid = group_id.unwrap_or(&env::var("KAFKA_GROUP_ID").unwrap_or_else(|_| "coreauto-step".into()));
    let consumer: StreamConsumer = match base_config()
        .set("group.id", gid)
        .set("auto.offset.reset", &env::var("KAFKA_AUTO_OFFSET_RESET").unwrap_or_else(|_| "earliest".into()))
        .create()
    {
        Ok(c) => c,
        Err(e) => return transport_error(&e.to_string()),
    };
    if let Err(e) = consumer.subscribe(&[topic]) { return transport_error(&e.to_string()); }
    let mut messages = Vec::new();
    let mut deadline = timeout_sec;
    while messages.len() < max_messages && deadline > 0.0 {
        match consumer.poll(Duration::from_secs_f64(deadline.min(1.0))) {
            None => { deadline -= 1.0; }
            Some(Ok(m)) => {
                let body = m.payload().map(|p| String::from_utf8_lossy(p).to_string()).unwrap_or_default();
                let val: Value = serde_json::from_str(&body).unwrap_or(Value::String(body));
                messages.push(json!({
                    "topic": m.topic(),
                    "partition": m.partition(),
                    "offset": m.offset(),
                    "key": m.key().map(|k| String::from_utf8_lossy(k).to_string()),
                    "value": val
                }));
            }
            Some(Err(e)) => return json!({"status_code":500,"error":e.to_string()}),
        }
    }
    json!({"status_code":200,"messages":messages})
}
