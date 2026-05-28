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
// Azure Service Bus helpers for Core Auto. Send from step scripts; Receive for ingress bridges only.

package servicebusclient

import (
	"context"
	"encoding/json"
	"os"
	"time"

	"github.com/Azure/azure-sdk-for-go/sdk/messaging/azservicebus"
	"github.com/core-df/coreauto-scripts-pub/queues/servicebus/Go/internal/result"
)

func connectionString() string {
	return os.Getenv("SERVICE_BUS_CONNECTION_STRING")
}

func queueName(explicit string) string {
	if explicit != "" {
		return explicit
	}
	return os.Getenv("SERVICE_BUS_QUEUE_NAME")
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

// Init verifies Service Bus connection settings.
func Init() result.Result {
	if connectionString() == "" {
		return result.MissingEnv("SERVICE_BUS_CONNECTION_STRING")
	}
	if os.Getenv("SERVICE_BUS_QUEUE_NAME") == "" {
		return result.MissingEnv("SERVICE_BUS_QUEUE_NAME (or pass queue per call)")
	}
	return result.Result{StatusCode: 200}
}

// Send publishes a message to a Service Bus queue.
func Send(value any, queue string) result.Result {
	conn := connectionString()
	q := queueName(queue)
	if conn == "" {
		return result.MissingEnv("SERVICE_BUS_CONNECTION_STRING")
	}
	if q == "" {
		return result.MissingEnv("SERVICE_BUS_QUEUE_NAME")
	}
	ctx := context.Background()
	client, err := azservicebus.NewClientFromConnectionString(conn, nil)
	if err != nil {
		return result.TransportError(err.Error())
	}
	sender, err := client.NewSender(q, nil)
	if err != nil {
		return result.TransportError(err.Error())
	}
	defer sender.Close(ctx)

	if err := sender.SendMessage(ctx, &azservicebus.Message{Body: encode(value)}, nil); err != nil {
		return result.TransportError(err.Error())
	}
	return result.Result{StatusCode: 200}
}

// Receive receives messages from a Service Bus queue (ingress bridges only).
func Receive(queue string, timeoutSec float64, maxMessages int, complete bool) result.Result {
	conn := connectionString()
	q := queueName(queue)
	if conn == "" {
		return result.MissingEnv("SERVICE_BUS_CONNECTION_STRING")
	}
	if q == "" {
		return result.MissingEnv("SERVICE_BUS_QUEUE_NAME")
	}
	if maxMessages < 1 {
		maxMessages = 1
	}
	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(timeoutSec*float64(time.Second)))
	defer cancel()

	client, err := azservicebus.NewClientFromConnectionString(conn, nil)
	if err != nil {
		return result.TransportError(err.Error())
	}
	receiver, err := client.NewReceiverForQueue(q, nil)
	if err != nil {
		return result.TransportError(err.Error())
	}
	defer receiver.Close(ctx)

	batch, err := receiver.ReceiveMessages(ctx, maxMessages, nil)
	if err != nil {
		return result.TransportError(err.Error())
	}
	messages := make([]map[string]any, 0, len(batch))
	for _, msg := range batch {
		raw := msg.Body
		messages = append(messages, map[string]any{
			"queue":      q,
			"message_id": msg.MessageID,
			"value":      decode(raw),
		})
		if complete {
			if err := receiver.CompleteMessage(ctx, msg, nil); err != nil {
				return result.TransportError(err.Error())
			}
		}
	}
	return result.Result{StatusCode: 200, Messages: messages}
}
