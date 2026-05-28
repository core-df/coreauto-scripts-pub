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
// IBM MQ helpers for Core Auto. Put from step scripts; Get for ingress bridges only.
// Go equivalent of Python pymqi: github.com/ibm-messaging/mq-golang (build tag ibmmq).

package ibmmqclient

import (
	"encoding/json"
	"os"

	"github.com/core-df/coreauto-scripts-pub/queues/ibmmq/Go/internal/result"
)

func queueName(explicit string) string {
	if explicit != "" {
		return explicit
	}
	return os.Getenv("MQ_QUEUE")
}

func encode(value any) []byte {
	switch v := value.(type) {
	case []byte:
		return v
	case string:
		return []byte(v)
	default:
		b, _ := json.Marshal(value)
		return b
	}
}

func decode(raw []byte) any {
	var body any
	if err := json.Unmarshal(raw, &body); err == nil {
		return body
	}
	return string(raw)
}

// Init verifies IBM MQ connection settings.
func Init() result.Result {
	if os.Getenv("MQ_HOST") == "" || os.Getenv("MQ_QUEUE_MANAGER") == "" {
		return result.MissingEnv("MQ_HOST and MQ_QUEUE_MANAGER")
	}
	if os.Getenv("MQ_QUEUE") == "" {
		return result.MissingEnv("MQ_QUEUE (or pass queue per call)")
	}
	return result.Result{StatusCode: 200}
}

// Put sends a message to an IBM MQ queue.
func Put(value any, queue string) result.Result {
	qname := queueName(queue)
	if qname == "" {
		return result.MissingEnv("MQ_QUEUE")
	}
	return mqPut(qname, encode(value))
}

// Get receives messages from an IBM MQ queue (ingress bridges only).
func Get(queue string, timeoutSec float64, maxMessages int) result.Result {
	qname := queueName(queue)
	if qname == "" {
		return result.MissingEnv("MQ_QUEUE")
	}
	if maxMessages < 1 {
		maxMessages = 1
	}
	return mqGet(qname, timeoutSec, maxMessages)
}
