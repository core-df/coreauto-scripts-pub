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
// Google Cloud Pub/Sub helpers for Core Auto. Publish from step scripts; Pull for ingress bridges only.

package pubsubclient

import (
	"context"
	"encoding/json"
	"os"
	"time"

	"cloud.google.com/go/pubsub"
	"github.com/core-df/coreauto-scripts-pub/queues/pubsub/Go/internal/result"
)

func projectID() string {
	if v := os.Getenv("PUBSUB_PROJECT_ID"); v != "" {
		return v
	}
	return os.Getenv("GOOGLE_CLOUD_PROJECT")
}

func topicID(explicit string) string {
	if explicit != "" {
		return explicit
	}
	return os.Getenv("PUBSUB_TOPIC_ID")
}

func subscriptionID(explicit string) string {
	if explicit != "" {
		return explicit
	}
	return os.Getenv("PUBSUB_SUBSCRIPTION_ID")
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

// Init verifies Google Cloud project configuration.
func Init() result.Result {
	if projectID() == "" {
		return result.MissingEnv("PUBSUB_PROJECT_ID or GOOGLE_CLOUD_PROJECT")
	}
	return result.Result{StatusCode: 200}
}

// Publish sends a message to a Pub/Sub topic.
func Publish(value any, topic string) result.Result {
	project := projectID()
	topicName := topicID(topic)
	if project == "" {
		return result.MissingEnv("PUBSUB_PROJECT_ID or GOOGLE_CLOUD_PROJECT")
	}
	if topicName == "" {
		return result.MissingEnv("PUBSUB_TOPIC_ID")
	}
	ctx := context.Background()
	client, err := pubsub.NewClient(ctx, project)
	if err != nil {
		return result.TransportError(err.Error())
	}
	defer client.Close()

	t := client.Topic(topicName)
	ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()
	id, err := t.Publish(ctx, &pubsub.Message{Data: encode(value)}).Get(ctx)
	if err != nil {
		return result.TransportError(err.Error())
	}
	return result.Result{StatusCode: 200, MessageID: id}
}

// Pull receives messages from a subscription (ingress bridges only).
func Pull(subscription string, maxMessages int, timeoutSec float64, ack bool) result.Result {
	project := projectID()
	subID := subscriptionID(subscription)
	if project == "" {
		return result.MissingEnv("PUBSUB_PROJECT_ID or GOOGLE_CLOUD_PROJECT")
	}
	if subID == "" {
		return result.MissingEnv("PUBSUB_SUBSCRIPTION_ID")
	}
	if maxMessages < 1 {
		maxMessages = 1
	}
	if maxMessages > 1000 {
		maxMessages = 1000
	}
	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(timeoutSec*float64(time.Second)))
	defer cancel()

	client, err := pubsub.NewClient(ctx, project)
	if err != nil {
		return result.TransportError(err.Error())
	}
	defer client.Close()

	sub := client.Subscription(subID)
	sub.ReceiveSettings.MaxOutstandingMessages = maxMessages
	sub.ReceiveSettings.NumGoroutines = 1

	messages := make([]map[string]any, 0, maxMessages)
	var recvErr error

	cctx, ccancel := context.WithCancel(ctx)
	defer ccancel()

	err = sub.Receive(cctx, func(_ context.Context, msg *pubsub.Message) {
		if len(messages) >= maxMessages {
			ccancel()
			return
		}
		messages = append(messages, map[string]any{
			"subscription": subID,
			"message_id":   msg.ID,
			"value":        decode(msg.Data),
		})
		if ack {
			msg.Ack()
		} else {
			msg.Nack()
		}
		if len(messages) >= maxMessages {
			ccancel()
		}
	})
	if err != nil && err != context.Canceled {
		recvErr = err
	}
	if recvErr != nil {
		return result.TransportError(recvErr.Error())
	}
	return result.Result{StatusCode: 200, Messages: messages}
}
