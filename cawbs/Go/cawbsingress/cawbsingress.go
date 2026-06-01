// Copyright Core DF

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
// Core Auto Web Services — ingress client for the Collector.
//
// Use outside step scripts (queue bridges, schedulers, file watchers) to submit
// events and flags that trigger Core Auto real-time or batch workflows.
//
// Documentation: https://coreauto.coredf.com/resources
//
// Required environment variables:
//
//	ENV            - Target environment name (Environment header).
//	CA_ACCESS_CODE - API access code used to obtain a bearer token.
//	CA_WBS_URL     - Base URL of the Core Auto Collector web service.
//
// Typical usage:
//
//	result := cawbsingress.Init()
//	if result.StatusCode != 200 { ... }
//	cawbsingress.PostEvent("OrderCreated", map[string]any{"orderId": "123"})
package cawbsingress

import (
	"os"

	"github.com/core-df/coreauto-scripts-pub/cawbs/Go/internal/wbs"
)

var (
	sess       wbs.Session
	env        string
	accessCode string
	baseURL    string
)

func loadIngressEnv() {
	env = os.Getenv("ENV")
	accessCode = os.Getenv("CA_ACCESS_CODE")
	baseURL = os.Getenv("CA_WBS_URL")
}

// Init authenticates with the Collector (no ACTIONID / STEPNAME required).
func Init() wbs.Result {
	loadIngressEnv()
	if env == "" || accessCode == "" || baseURL == "" {
		return wbs.MissingEnv("ENV, CA_ACCESS_CODE, CA_WBS_URL")
	}
	return sess.Authenticate(env, accessCode, baseURL)
}

// PostEvent submits an event to the Collector (POST /v1/rtevent).
func PostEvent(eventName string, payload any, eventSource ...string) wbs.Result {
	src := ""
	if len(eventSource) > 0 {
		src = eventSource[0]
	}
	return sess.PostEvent(eventName, payload, src)
}

// GetEventStatus returns execution status for an action (GET /v1/rtevent/status/{actionid}).
func GetEventStatus(actionID int) wbs.Result {
	return sess.GetEventStatus(actionID)
}

// GetEventList lists available event definitions (GET /v1/rtevent/list).
func GetEventList() wbs.Result {
	return sess.GetEventList()
}

// SubmitFlag submits a batch flag (POST /v1/flag). Date format: YYYY-MM-DD.
func SubmitFlag(name, systemName, sourceSystemName, date string) wbs.Result {
	return sess.SubmitFlag(name, systemName, sourceSystemName, date)
}

// GetKeystore fetches one or more secrets from the Collector keystore.
func GetKeystore(keylist string) wbs.Result {
	return sess.GetKeystore(keylist)
}
