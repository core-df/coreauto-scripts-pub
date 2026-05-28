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
// Core Auto real-time step — full integration example (Go port).

package main

import (
	"encoding/json"
	"fmt"
	"os"

	"github.com/core-df/coreauto-scripts-pub/cawbs/Go/cawbs"
	"github.com/core-df/coreauto-scripts-pub/cawbs/Go/internal/wbs"
	fileresult "github.com/core-df/coreauto-scripts-pub/files/Go/internal/result"
	"github.com/core-df/coreauto-scripts-pub/files/Go/fileclient"
	"github.com/core-df/coreauto-scripts-pub/queues/kafka/Go/kafkaclient"
	"github.com/core-df/coreauto-scripts-pub/queues/rabbit/Go/rabbitclient"
	"github.com/core-df/coreauto-scripts-pub/queues/redis/Go/redisclient"
	"github.com/core-df/coreauto-scripts-pub/queues/sqs/Go/sqsclient"
	transformresult "github.com/core-df/coreauto-scripts-pub/transform/Go/internal/result"
	"github.com/core-df/coreauto-scripts-pub/transform/Go/transformclient"
)

func mustWbs(label string, r wbs.Result) wbs.Result {
	if r.StatusCode >= 400 || r.StatusCode == 0 {
		b, _ := json.Marshal(r)
		fmt.Fprintf(os.Stderr, "%s: %s\n", label, b)
		os.Exit(1)
	}
	return r
}

func mustTransform(label string, r transformresult.Result) transformresult.Result {
	if r.StatusCode >= 400 || r.StatusCode == 0 {
		fmt.Fprintf(os.Stderr, "%s: %+v\n", label, r)
		os.Exit(1)
	}
	return r
}

func mustFile(label string, r fileresult.Result) fileresult.Result {
	if r.StatusCode >= 400 || r.StatusCode == 0 {
		fmt.Fprintf(os.Stderr, "%s: %+v\n", label, r)
		os.Exit(1)
	}
	return r
}

func optionalQueue(label string, statusCode int, err any) bool {
	if statusCode >= 400 || statusCode == 0 {
		fmt.Printf("[warn] %s: %v\n", label, err)
		return false
	}
	fmt.Printf("[ok] %s\n", label)
	return true
}

func orderIDFromEvent(event wbs.Result) string {
	if m, ok := event.Payload.(map[string]any); ok {
		if id, ok := m["orderId"].(string); ok && id != "" {
			return id
		}
		if id, ok := m["id"].(string); ok && id != "" {
			return id
		}
	}
	return "unknown"
}

func main() {
	mustWbs("cawbs.Init", cawbs.Init())
	event := mustWbs("cawbs.GetEventPayload", cawbs.GetEventPayload())
	orderID := orderIDFromEvent(event)

	ackDir := os.Getenv("EXAMPLE_ACK_DIR")
	if ackDir == "" {
		ackDir = "/tmp/coreauto-example"
	}
	ackPath := ackDir + "/" + orderID + ".json"

	order := map[string]any{"orderId": orderID, "details": event.Payload}
	body := mustTransform("transform.JsonStringify", transformclient.JsonStringify(order, nil))
	mustFile("files.LocalWrite", fileclient.LocalWrite(ackPath, body.Text, ""))

	payload := map[string]any{"orderId": orderID}
	topic := getenv("EXAMPLE_KAFKA_TOPIC", "orders.enriched")
	queue := getenv("EXAMPLE_QUEUE_NAME", "orders")
	published := []string{}
	if kr := kafkaclient.Produce(topic, payload, ""); optionalQueue("kafka", kr.StatusCode, kr.Error) {
		published = append(published, "kafka")
	}
	if rr := rabbitclient.Publish(queue, payload); optionalQueue("rabbit", rr.StatusCode, rr.Error) {
		published = append(published, "rabbit")
	}
	if sr := sqsclient.Send(payload); optionalQueue("sqs", sr.StatusCode, sr.Error) {
		published = append(published, "sqs")
	}
	if rd := redisclient.Push(queue, payload); optionalQueue("redis", rd.StatusCode, rd.Error) {
		published = append(published, "redis")
	}

	out := map[string]any{"orderId": orderID, "queuesPublished": published, "ackPath": ackPath}
	mustWbs("cawbs.PutStepPayload", cawbs.PutStepPayload(out))
	enc, _ := json.MarshalIndent(map[string]any{"status_code": 200, "result": out}, "", "  ")
	fmt.Println(string(enc))
}

func getenv(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}
