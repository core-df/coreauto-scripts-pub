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
// NATS helpers for Core Auto. Publish from step scripts; Subscribe for ingress bridges only.

package natsclient

import (
	"encoding/json"
	"os"
	"time"

	"github.com/core-df/coreauto-scripts-pub/queues/nats/Go/internal/result"
	"github.com/nats-io/nats.go"
)

func servers() string {
	if v := os.Getenv("NATS_URL"); v != "" {
		return v
	}
	return os.Getenv("NATS_SERVERS")
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

// Init verifies NATS server settings.
func Init() result.Result {
	if servers() == "" {
		return result.MissingEnv("NATS_URL or NATS_SERVERS")
	}
	return result.Result{StatusCode: 200}
}

// Publish sends a message to a NATS subject.
func Publish(subject string, value any) result.Result {
	if servers() == "" {
		return result.MissingEnv("NATS_URL or NATS_SERVERS")
	}
	nc, err := nats.Connect(servers())
	if err != nil {
		return result.TransportError(err.Error())
	}
	defer nc.Drain()

	if err := nc.Publish(subject, encode(value)); err != nil {
		return result.TransportError(err.Error())
	}
	if err := nc.Flush(); err != nil {
		return result.TransportError(err.Error())
	}
	return result.Result{StatusCode: 200}
}

// Subscribe polls messages on a subject (ingress bridges only).
func Subscribe(subject string, timeoutSec float64, maxMessages int) result.Result {
	if servers() == "" {
		return result.MissingEnv("NATS_URL or NATS_SERVERS")
	}
	nc, err := nats.Connect(servers())
	if err != nil {
		return result.TransportError(err.Error())
	}
	defer nc.Drain()

	sub, err := nc.SubscribeSync(subject)
	if err != nil {
		return result.TransportError(err.Error())
	}

	messages := make([]map[string]any, 0, maxMessages)
	deadline := timeoutSec
	for len(messages) < maxMessages && deadline > 0 {
		wait := 1.0
		if deadline < wait {
			wait = deadline
		}
		msg, err := sub.NextMsg(time.Duration(wait * float64(time.Second)))
		deadline -= wait
		if err != nil {
			if err == nats.ErrTimeout {
				continue
			}
			return result.TransportError(err.Error())
		}
		messages = append(messages, map[string]any{
			"subject": msg.Subject,
			"value":   decode(msg.Data),
		})
	}
	return result.Result{StatusCode: 200, Messages: messages}
}
