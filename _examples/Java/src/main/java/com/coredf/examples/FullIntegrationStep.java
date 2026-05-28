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
// Core Auto real-time step — full integration example (Java port).

package com.coredf.examples;

import com.coredf.cawbs.Cawbs;
import com.coredf.cawbs.Result;
import com.coredf.files.FileClient;
import com.coredf.kafka.KafkaClient;
import com.coredf.transform.TransformClient;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public final class FullIntegrationStep {
    public static void main(String[] args) {
        must("cawbs.Init", Cawbs.Init());
        Result event = must("cawbs.GetEventPayload", Cawbs.GetEventPayload());

        String orderId = "unknown";
        if (event.getPayload() instanceof Map<?, ?> payload) {
            Object id = payload.get("orderId");
            if (id == null) id = payload.get("id");
            if (id != null) orderId = String.valueOf(id);
        }

        String ackDir = System.getenv().getOrDefault("EXAMPLE_ACK_DIR", "/tmp/coreauto-example");
        String ackPath = ackDir + "/" + orderId + ".json";

        Map<String, Object> order = new HashMap<>();
        order.put("orderId", orderId);
        order.put("details", event.getPayload());

        com.coredf.transform.Result text = mustTransform(
                "transform.JsonStringify", TransformClient.JsonStringify(order));
        mustFile("files.LocalWrite", FileClient.LocalWrite(ackPath, String.valueOf(text.get("text"))));

        String topic = System.getenv().getOrDefault("EXAMPLE_KAFKA_TOPIC", "orders.enriched");
        List<String> published = new ArrayList<>();
        if (optionalQueue("kafka", KafkaClient.Produce(topic, order))) {
            published.add("kafka");
        }

        Map<String, Object> out = new HashMap<>();
        out.put("orderId", orderId);
        out.put("queuesPublished", published);
        out.put("ackPath", ackPath);
        must("cawbs.PutStepPayload", Cawbs.PutStepPayload(out));

        System.out.println("{\"status_code\":200,\"result\":" + out + "}");
    }

    private static Result must(String label, Result r) {
        if (r.getStatusCode() >= 400 || r.getStatusCode() == 0) {
            System.err.println(label + ": " + r.getError());
            System.exit(1);
        }
        return r;
    }

    private static com.coredf.transform.Result mustTransform(String label, com.coredf.transform.Result r) {
        if (r.getStatusCode() >= 400 || r.getStatusCode() == 0) {
            System.err.println(label + ": " + r.get("error"));
            System.exit(1);
        }
        return r;
    }

    private static com.coredf.files.Result mustFile(String label, com.coredf.files.Result r) {
        if (r.getStatusCode() >= 400 || r.getStatusCode() == 0) {
            System.err.println(label + ": " + r.get("error"));
            System.exit(1);
        }
        return r;
    }

    private static boolean optionalQueue(String label, com.coredf.kafka.Result r) {
        if (r.getStatusCode() >= 400 || r.getStatusCode() == 0) {
            System.out.println("[warn] " + label);
            return false;
        }
        System.out.println("[ok] " + label);
        return true;
    }
}
