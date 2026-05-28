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
// Queue ingress bridge — consume from a queue and submit Core Auto events via cawbsingress.
//
// Run as a long-lived process on a worker or sidecar, NOT inside a Core Auto step.

package ingressclient

import (
	"os"

	"github.com/core-df/coreauto-scripts-pub/cawbs/Go/cawbsingress"
	"github.com/core-df/coreauto-scripts-pub/queues/ingress/Go/internal/result"
)

// ConsumeResult holds the outcome of a queue consume operation.
type ConsumeResult struct {
	StatusCode int
	Error      any
	Messages   []ConsumeMessage
}

// ConsumeMessage represents a single consumed queue message.
type ConsumeMessage struct {
	Value any
}

// ConsumeFunc polls messages from a queue backend.
type ConsumeFunc func() ConsumeResult

// TriggerEvent submits payload to the Collector as a real-time event (POST /v1/rtevent).
func TriggerEvent(payload any, eventName string, eventSource string) result.Result {
	name := eventName
	if name == "" {
		name = os.Getenv("CA_EVENT_NAME")
	}
	if name == "" {
		return result.MissingEnv("CA_EVENT_NAME (or pass event_name)")
	}

	source := eventSource
	if source == "" {
		source = os.Getenv("CA_EVENT_SOURCE")
	}

	init := cawbsingress.Init()
	if init.StatusCode >= 400 {
		return copyEventResult(init.StatusCode, init.Error, init.ActionID, init.EventID)
	}

	if source != "" {
		post := cawbsingress.PostEvent(name, payload, source)
		return copyEventResult(post.StatusCode, post.Error, post.ActionID, post.EventID)
	}
	post := cawbsingress.PostEvent(name, payload)
	return copyEventResult(post.StatusCode, post.Error, post.ActionID, post.EventID)
}

// ForwardMessages forwards messages from a queue client consume result to Core Auto.
func ForwardMessages(consume ConsumeResult) result.Result {
	if consume.StatusCode != 200 {
		return result.Result{StatusCode: consume.StatusCode, Error: consume.Error}
	}

	forwarded := make([]map[string]any, 0, len(consume.Messages))
	for _, msg := range consume.Messages {
		ev := TriggerEvent(msg.Value, "", "")
		if ev.StatusCode >= 400 {
			return ev
		}
		forwarded = append(forwarded, map[string]any{
			"actionId": ev.ActionID,
			"eventId":  ev.EventID,
		})
	}
	return result.Result{StatusCode: 200, Forwarded: forwarded}
}

// RunBridge consumes once from a queue backend and forwards all messages as events.
func RunBridge(consume ConsumeFunc) result.Result {
	return ForwardMessages(consume())
}

func copyEventResult(statusCode int, err, actionID, eventID any) result.Result {
	return result.Result{
		StatusCode: statusCode,
		Error:      err,
		ActionID:   actionID,
		EventID:    eventID,
	}
}
