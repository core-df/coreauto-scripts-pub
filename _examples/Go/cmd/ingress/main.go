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
// Kafka ingress bridge — Go port.

package main

import (
	"encoding/json"
	"fmt"
	"os"
	"time"

	"github.com/core-df/coreauto-scripts-pub/queues/ingress/Go/ingressclient"
	"github.com/core-df/coreauto-scripts-pub/queues/kafka/Go/kafkaclient"
)

func main() {
	topic := os.Getenv("EXAMPLE_KAFKA_TOPIC")
	if topic == "" {
		topic = "orders.inbound"
	}
	fmt.Fprintf(os.Stderr, "Bridging Kafka topic %q\n", topic)
	for {
		r := ingressclient.RunBridge(func() ingressclient.ConsumeResult {
			cr := kafkaclient.Consume(topic, 30, 10, "")
			msgs := make([]ingressclient.ConsumeMessage, 0)
			if raw, ok := cr.Messages.([]map[string]any); ok {
				for _, m := range raw {
					msgs = append(msgs, ingressclient.ConsumeMessage{Value: m["value"]})
				}
			}
			return ingressclient.ConsumeResult{
				StatusCode: cr.StatusCode,
				Error:      cr.Error,
				Messages:   msgs,
			}
		})
		if r.StatusCode >= 400 || r.StatusCode == 0 {
			b, _ := json.Marshal(r)
			fmt.Fprintln(os.Stderr, string(b))
			time.Sleep(5 * time.Second)
			continue
		}
		if r.Forwarded != nil {
			b, _ := json.Marshal(map[string]any{"forwarded": r.Forwarded})
			if len(string(b)) > 20 {
				fmt.Println(string(b))
			}
		}
	}
}
