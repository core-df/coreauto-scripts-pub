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
// Kafka ingress bridge — Rust port.

use coreauto_ingress::ingress;
use coreauto_kafka::consume;
use std::thread;
use std::time::Duration;

fn main() {
    let topic = std::env::var("EXAMPLE_KAFKA_TOPIC").unwrap_or_else(|_| "orders.inbound".into());
    eprintln!("Bridging Kafka topic {topic}");
    loop {
        let topic = topic.clone();
        let result = ingress::run_bridge(|| {
            consume(&topic, 30.0, 10, None)
        });
        let code = result.get("status_code").and_then(|v| v.as_i64()).unwrap_or(0);
        if code >= 400 || code == 0 {
            eprintln!("{result}");
            thread::sleep(Duration::from_secs(5));
            continue;
        }
        if result
            .get("forwarded")
            .and_then(|v| v.as_array())
            .is_some_and(|a| !a.is_empty())
        {
            println!("{result}");
        }
    }
}
