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
// RabbitMQ helpers for Core Auto. Publish from step scripts; Consume for ingress bridges only.

package rabbitclient

import (
	"context"
	"encoding/json"
	"net/url"
	"os"
	"time"

	amqp "github.com/rabbitmq/amqp091-go"
	"github.com/core-df/coreauto-scripts-pub/queues/rabbit/Go/internal/result"
)

func connectionURL() string {
	if u := os.Getenv("RABBITMQ_URL"); u != "" {
		return u
	}
	host := os.Getenv("RABBITMQ_HOST")
	if host == "" {
		return ""
	}
	port := os.Getenv("RABBITMQ_PORT")
	if port == "" {
		port = "5672"
	}
	user := url.QueryEscape(os.Getenv("RABBITMQ_USER"))
	if user == "" {
		user = "guest"
	}
	password := url.QueryEscape(os.Getenv("RABBITMQ_PASSWORD"))
	if password == "" {
		password = "guest"
	}
	vhost := url.QueryEscape(os.Getenv("RABBITMQ_VHOST"))
	if vhost == "" {
		vhost = "%2F"
	} else if vhost == "/" {
		vhost = "%2F"
	}
	return "amqp://" + user + ":" + password + "@" + host + ":" + port + "/" + vhost
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

// Init verifies RabbitMQ connection settings.
func Init() result.Result {
	if connectionURL() == "" {
		return result.MissingEnv("RABBITMQ_URL or RABBITMQ_HOST")
	}
	return result.Result{StatusCode: 200}
}

// Publish sends a message to a queue.
func Publish(queue string, value any, durable bool) result.Result {
	connURL := connectionURL()
	if connURL == "" {
		return result.MissingEnv("RABBITMQ_URL or RABBITMQ_HOST")
	}
	conn, err := amqp.Dial(connURL)
	if err != nil {
		return result.TransportError(err.Error())
	}
	defer conn.Close()

	ch, err := conn.Channel()
	if err != nil {
		return result.TransportError(err.Error())
	}
	defer ch.Close()

	if _, err := ch.QueueDeclare(queue, durable, false, false, false, nil); err != nil {
		return result.TransportError(err.Error())
	}
	if err := ch.PublishWithContext(
		context.Background(),
		"",
		queue,
		false,
		false,
		amqp.Publishing{Body: encode(value)},
	); err != nil {
		return result.TransportError(err.Error())
	}
	return result.Result{StatusCode: 200}
}

// Consume polls messages from a queue (ingress bridges only).
func Consume(queue string, timeoutSec float64, maxMessages int, autoAck bool, durable bool) result.Result {
	connURL := connectionURL()
	if connURL == "" {
		return result.MissingEnv("RABBITMQ_URL or RABBITMQ_HOST")
	}
	conn, err := amqp.Dial(connURL)
	if err != nil {
		return result.TransportError(err.Error())
	}
	defer conn.Close()

	ch, err := conn.Channel()
	if err != nil {
		return result.TransportError(err.Error())
	}
	defer ch.Close()

	if _, err := ch.QueueDeclare(queue, durable, false, false, false, nil); err != nil {
		return result.TransportError(err.Error())
	}

	deliveries, err := ch.Consume(queue, "", autoAck, false, false, false, nil)
	if err != nil {
		return result.TransportError(err.Error())
	}

	messages := make([]map[string]any, 0, maxMessages)
	deadline := time.After(time.Duration(timeoutSec * float64(time.Second)))
	for len(messages) < maxMessages {
		select {
		case d, ok := <-deliveries:
			if !ok {
				return result.Result{StatusCode: 200, Messages: messages}
			}
			messages = append(messages, map[string]any{
				"queue":        queue,
				"delivery_tag": d.DeliveryTag,
				"value":        decode(d.Body),
			})
			if !autoAck {
				_ = d.Ack(false)
			}
		case <-deadline:
			return result.Result{StatusCode: 200, Messages: messages}
		}
	}
	return result.Result{StatusCode: 200, Messages: messages}
}
