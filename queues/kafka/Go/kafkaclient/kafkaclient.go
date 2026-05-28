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
// Kafka helpers for Core Auto. Produce from step scripts; Consume for ingress bridges only.

package kafkaclient

import (
	"encoding/json"
	"os"
	"time"

	"github.com/confluentinc/confluent-kafka-go/v2/kafka"
	"github.com/core-df/coreauto-scripts-pub/queues/kafka/Go/internal/result"
)

func bootstrap() string {
	return os.Getenv("KAFKA_BOOTSTRAP_SERVERS")
}

func config(extra map[string]any) *kafka.ConfigMap {
	cfg := kafka.ConfigMap{"bootstrap.servers": bootstrap()}
	if v := os.Getenv("KAFKA_SECURITY_PROTOCOL"); v != "" {
		cfg["security.protocol"] = v
	}
	if v := os.Getenv("KAFKA_SASL_MECHANISM"); v != "" {
		cfg["sasl.mechanism"] = v
	}
	if v := os.Getenv("KAFKA_SASL_USERNAME"); v != "" {
		cfg["sasl.username"] = v
	}
	if v := os.Getenv("KAFKA_SASL_PASSWORD"); v != "" {
		cfg["sasl.password"] = v
	}
	for k, v := range extra {
		cfg[k] = v
	}
	return &cfg
}

func encodeValue(value any) []byte {
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

func decodeValue(raw []byte) any {
	var body any
	if err := json.Unmarshal(raw, &body); err == nil {
		return body
	}
	return string(raw)
}

// Init verifies KAFKA_BOOTSTRAP_SERVERS is set.
func Init() result.Result {
	if bootstrap() == "" {
		return result.MissingEnv("KAFKA_BOOTSTRAP_SERVERS")
	}
	return result.Result{StatusCode: 200}
}

// Produce publishes a message to a topic.
func Produce(topic string, value any, key string) result.Result {
	if bootstrap() == "" {
		return result.MissingEnv("KAFKA_BOOTSTRAP_SERVERS")
	}
	producer, err := kafka.NewProducer(config(nil))
	if err != nil {
		return result.TransportError(err.Error())
	}
	defer producer.Close()

	payload := encodeValue(value)
	var keyBytes []byte
	if key != "" {
		keyBytes = []byte(key)
	}

	errCh := make(chan kafka.Event, 1)
	err = producer.Produce(&kafka.Message{
		TopicPartition: kafka.TopicPartition{Topic: &topic, Partition: kafka.PartitionAny},
		Key:            keyBytes,
		Value:          payload,
	}, errCh)
	if err != nil {
		return result.TransportError(err.Error())
	}

	select {
	case e := <-errCh:
		if msg, ok := e.(*kafka.Message); ok && msg.TopicPartition.Error != nil {
			return result.Result{StatusCode: 500, Error: msg.TopicPartition.Error.Error()}
		}
	case <-time.After(30 * time.Second):
		return result.TransportError("produce timeout")
	}
	producer.Flush(30 * 1000)
	return result.Result{StatusCode: 200}
}

// Consume polls messages from a topic (ingress bridges only).
func Consume(topic string, timeoutSec float64, maxMessages int, groupID string) result.Result {
	if bootstrap() == "" {
		return result.MissingEnv("KAFKA_BOOTSTRAP_SERVERS")
	}
	gid := groupID
	if gid == "" {
		gid = os.Getenv("KAFKA_GROUP_ID")
	}
	if gid == "" {
		gid = "coreauto-step"
	}
	offset := os.Getenv("KAFKA_AUTO_OFFSET_RESET")
	if offset == "" {
		offset = "earliest"
	}
	consumer, err := kafka.NewConsumer(config(map[string]any{
		"group.id":           gid,
		"auto.offset.reset":  offset,
	}))
	if err != nil {
		return result.TransportError(err.Error())
	}
	defer consumer.Close()

	if err := consumer.SubscribeTopics([]string{topic}, nil); err != nil {
		return result.TransportError(err.Error())
	}

	messages := make([]map[string]any, 0, maxMessages)
	deadline := timeoutSec
	for len(messages) < maxMessages && deadline > 0 {
		wait := 1.0
		if deadline < wait {
			wait = deadline
		}
		msg, err := consumer.ReadMessage(time.Duration(wait * float64(time.Second)))
		deadline -= wait
		if err != nil {
			if kafkaErr, ok := err.(kafka.Error); ok && kafkaErr.Code() == kafka.ErrTimedOut {
				continue
			}
			return result.TransportError(err.Error())
		}
		entry := map[string]any{
			"topic":     *msg.TopicPartition.Topic,
			"partition": msg.TopicPartition.Partition,
			"offset":    int64(msg.TopicPartition.Offset),
			"value":     decodeValue(msg.Value),
		}
		if msg.Key != nil {
			entry["key"] = string(msg.Key)
		}
		messages = append(messages, entry)
	}
	return result.Result{StatusCode: 200, Messages: messages}
}
