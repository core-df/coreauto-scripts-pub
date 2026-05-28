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
// Redis list helpers for Core Auto. Push from step scripts; Pop for ingress bridges only.

package redisclient

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"time"

	"github.com/core-df/coreauto-scripts-pub/queues/redis/Go/internal/result"
	"github.com/redis/go-redis/v9"
)

func connectionURL() string {
	if u := os.Getenv("REDIS_URL"); u != "" {
		return u
	}
	host := os.Getenv("REDIS_HOST")
	if host == "" {
		return ""
	}
	port := os.Getenv("REDIS_PORT")
	if port == "" {
		port = "6379"
	}
	password := os.Getenv("REDIS_PASSWORD")
	db := os.Getenv("REDIS_DB")
	if db == "" {
		db = "0"
	}
	if password != "" {
		return fmt.Sprintf("redis://:%s@%s:%s/%s", password, host, port, db)
	}
	return fmt.Sprintf("redis://%s:%s/%s", host, port, db)
}

func newClient() (*redis.Client, error) {
	opt, err := redis.ParseURL(connectionURL())
	if err != nil {
		return nil, err
	}
	return redis.NewClient(opt), nil
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

// Init verifies Redis connection settings.
func Init() result.Result {
	if connectionURL() == "" {
		return result.MissingEnv("REDIS_URL or REDIS_HOST")
	}
	return result.Result{StatusCode: 200}
}

// Push enqueues a value on a Redis list.
func Push(queue string, value any) result.Result {
	if connectionURL() == "" {
		return result.MissingEnv("REDIS_URL or REDIS_HOST")
	}
	client, err := newClient()
	if err != nil {
		return result.TransportError(err.Error())
	}
	defer client.Close()
	ctx := context.Background()
	if err := client.LPush(ctx, queue, encode(value)).Err(); err != nil {
		return result.TransportError(err.Error())
	}
	return result.Result{StatusCode: 200}
}

// Pop blocking-dequeues from a Redis list (ingress bridges only).
func Pop(queue string, timeoutSec float64, maxMessages int) result.Result {
	if connectionURL() == "" {
		return result.MissingEnv("REDIS_URL or REDIS_HOST")
	}
	if maxMessages < 1 {
		maxMessages = 1
	}
	client, err := newClient()
	if err != nil {
		return result.TransportError(err.Error())
	}
	defer client.Close()
	ctx := context.Background()

	messages := make([]map[string]any, 0, maxMessages)
	remaining := maxMessages
	deadline := timeoutSec
	for remaining > 0 {
		wait := 1
		if remaining == maxMessages {
			wait = int(timeoutSec)
			if wait < 1 {
				wait = 1
			}
		}
		item, err := client.BRPop(ctx, time.Duration(wait)*time.Second, queue).Result()
		if err == redis.Nil {
			break
		}
		if err != nil {
			return result.TransportError(err.Error())
		}
		if len(item) >= 2 {
			messages = append(messages, map[string]any{
				"queue": queue,
				"value": decode([]byte(item[1])),
			})
		}
		remaining--
		deadline -= float64(wait)
		if deadline <= 0 {
			break
		}
	}
	return result.Result{StatusCode: 200, Messages: messages}
}
