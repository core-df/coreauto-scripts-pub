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
// Batch-oriented variant of cawbs for scripts that only need authentication and
// keystore access (no real-time event or step payload APIs). Part of the
// coreauto-scripts-pub repository; not related to coreauto-mngr-pub
// (PostgreSQL-backed agents and workers).
//
// Documentation: https://coreauto.coredf.com/resources
//
// Required environment variables:
//
//	ENV            - Target environment name (sent as the Environment header).
//	CA_ACCESS_CODE - API access code used to obtain a bearer token.
//	CA_WBS_URL     - Base URL of the Core Auto Collector web service.
//
// Typical usage:
//
//	result := cawbsbatch.Init()
//	if result.StatusCode != 200 { ... }
//	secrets := cawbsbatch.GetKeystore("db_user,db_password")
package cawbsbatch

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

func loadBatchEnv() {
	env = os.Getenv("ENV")
	accessCode = os.Getenv("CA_ACCESS_CODE")
	baseURL = os.Getenv("CA_WBS_URL")
}

// Init authenticates with the Collector and prepares shared request headers.
func Init() wbs.Result {
	loadBatchEnv()
	if env == "" || accessCode == "" || baseURL == "" {
		return wbs.MissingEnv("ENV, CA_ACCESS_CODE, CA_WBS_URL")
	}
	return sess.Authenticate(env, accessCode, baseURL)
}

// GetKeystore fetches one or more secrets from the Collector keystore.
func GetKeystore(keylist string) wbs.Result {
	return sess.GetKeystore(keylist)
}
