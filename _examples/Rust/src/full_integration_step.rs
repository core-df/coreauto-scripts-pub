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
//
// Core Auto real-time step — full integration example (Rust port).

use cawbs::{Cawbs, Result as WbsResult};
use coreauto_files::local_write;
use coreauto_kafka::produce;
use coreauto_transform::json_stringify;
use serde_json::{json, Value};

fn must(label: &str, r: WbsResult) {
    if r.status_code >= 400 || r.status_code == 0 {
        eprintln!("{label}: {r:?}");
        std::process::exit(1);
    }
}

fn status_ok(v: &Value) -> bool {
    v.get("status_code").and_then(|c| c.as_i64()) == Some(200)
}

fn optional(label: &str, v: Value) -> bool {
    let code = v.get("status_code").and_then(|c| c.as_i64()).unwrap_or(0);
    let err = v.get("error").and_then(|e| e.as_str()).unwrap_or("").to_lowercase();
    if [601, 500].contains(&code) && err.contains("missing") {
        println!("[skip] {label}: not configured");
        return false;
    }
    if code >= 400 || code == 0 {
        println!("[warn] {label}: {err}");
        return false;
    }
    println!("[ok] {label}");
    true
}

fn order_id(event: &WbsResult) -> String {
    event
        .payload
        .as_ref()
        .and_then(|p| p.get("orderId").or_else(|| p.get("id")))
        .and_then(|v| v.as_str())
        .unwrap_or("unknown")
        .to_string()
}

fn main() {
    must("cawbs.init", Cawbs::init());
    let event = Cawbs::get_event_payload();
    must("cawbs.get_event_payload", event.clone());

    let order_id = order_id(&event);
    let ack_dir =
        std::env::var("EXAMPLE_ACK_DIR").unwrap_or_else(|_| "/tmp/coreauto-example".into());
    let ack_path = format!("{ack_dir}/{order_id}.json");

    let order = json!({ "orderId": order_id, "details": event.payload });
    let text = json_stringify(&order, None);
    if !status_ok(&text) {
        eprintln!("transform failed: {text}");
        std::process::exit(1);
    }
    let body = text.get("text").and_then(|v| v.as_str()).unwrap_or("");
    let wr = local_write(&ack_path, body);
    if !status_ok(&wr) {
        eprintln!("write failed: {wr}");
        std::process::exit(1);
    }

    let topic = std::env::var("EXAMPLE_KAFKA_TOPIC").unwrap_or_else(|_| "orders.enriched".into());
    let mut published = Vec::new();
    if optional(
        "queues.kafka",
        produce(&topic, order.clone(), None),
    ) {
        published.push("kafka");
    }

    let out = json!({
        "orderId": order_id,
        "queuesPublished": published,
        "ackPath": ack_path
    });
    must("cawbs.put_step_payload", Cawbs::put_step_payload(out.clone()));
    println!("{}", json!({ "status_code": 200, "result": out }));
}
