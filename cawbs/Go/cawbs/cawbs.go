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
// Core Auto Web Services library (cawbs) — Go client for the Core Auto Collector.
//
// Provides HTTP access to the Core Auto Collector REST API for real-time step scripts.
// Part of the coreauto-scripts-pub repository; not related to coreauto-mngr-pub
// (PostgreSQL-backed agents and workers).
//
// Documentation: https://coreauto.coredf.com/resources
//
// Required environment variables:
//
//	ENV            - Target environment name (sent as the Environment header).
//	ACTIONID       - Real-time action identifier for the current run.
//	CA_ACCESS_CODE - API access code used to obtain a bearer token.
//	CA_WBS_URL     - Base URL of the Core Auto Collector web service.
//	STEPNAME       - Name of the current step (used by PutStepPayload).
//
// Typical usage:
//
//	result := cawbs.Init()
//	if result.StatusCode != 200 { ... }
//	payload := cawbs.GetEventPayload()
//	cawbs.PutStepPayload(map[string]any{"key": "value"})
package cawbs

import (
	"os"

	"github.com/core-df/coreauto-scripts-pub/cawbs/Go/internal/wbs"
)

var (
	sess       wbs.Session
	env        = os.Getenv("ENV")
	actionID   = os.Getenv("ACTIONID")
	accessCode = os.Getenv("CA_ACCESS_CODE")
	baseURL    = os.Getenv("CA_WBS_URL")
	stepName   = os.Getenv("STEPNAME")
)

// Init authenticates with the Collector and prepares shared request headers.
func Init() wbs.Result {
	if env == "" || actionID == "" || accessCode == "" || baseURL == "" || stepName == "" {
		return wbs.MissingEnv("ENV, ACTIONID, CA_ACCESS_CODE, CA_WBS_URL, STEPNAME")
	}
	return sess.Authenticate(env, accessCode, baseURL)
}

// GetEventPayload fetches the inbound event payload for the current ACTIONID.
func GetEventPayload() wbs.Result {
	return sess.GetEventPayload(actionID)
}

// PutStepPayload stores the output payload for the current step.
func PutStepPayload(payload any) wbs.Result {
	return sess.PutStepPayload(actionID, stepName, payload)
}

// GetStepPayload retrieves a prior step's stored payload for the current ACTIONID.
func GetStepPayload(stepname string) wbs.Result {
	return sess.GetStepPayload(actionID, stepname)
}

// GetKeystore fetches one or more secrets from the Collector keystore.
func GetKeystore(keylist string) wbs.Result {
	return sess.GetKeystore(keylist)
}
