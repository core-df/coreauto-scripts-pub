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
// Kafka ingress bridge — Java port.

package com.coredf.examples;

import com.coredf.ingress.Ingress;
import com.coredf.kafka.KafkaClient;

public final class FullIntegrationIngress {
    public static void main(String[] args) throws InterruptedException {
        String topic = System.getenv().getOrDefault("EXAMPLE_KAFKA_TOPIC", "orders.inbound");
        System.err.println("Bridging Kafka topic " + topic);
        while (true) {
            var r = Ingress.RunBridge(() -> KafkaClient.Consume(topic, 30, 10, null));
            if (r.getStatusCode() >= 400 || r.getStatusCode() == 0) {
                System.err.println(r.get("error"));
                Thread.sleep(5000);
                continue;
            }
            if (r.get("forwarded") != null) {
                System.out.println(r.toMap());
            }
        }
    }
}
