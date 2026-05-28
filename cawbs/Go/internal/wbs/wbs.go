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
// Shared HTTP helpers for the Core Auto Collector (cawbs) Go client.

package wbs

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
)

// Result mirrors the dict return values of the Python cawbs modules.
type Result struct {
	StatusCode int            `json:"status_code"`
	Error      any            `json:"error,omitempty"`
	Payload    any            `json:"payload,omitempty"`
	Answer     map[string]any `json:"answer,omitempty"`
}

// Session holds authenticated Collector request state.
type Session struct {
	initialized bool
	baseURL     string
	headers     http.Header
}

func (s *Session) Initialized() bool {
	return s.initialized
}

// Authenticate exchanges an API access code for a bearer token.
func (s *Session) Authenticate(env, accessCode, baseURL string) Result {
	if s.initialized {
		return Result{StatusCode: 602, Error: "init already called"}
	}

	baseURL = strings.Trim(baseURL, "/ ")
	body, err := json.Marshal(map[string]string{"apiCode": accessCode})
	if err != nil {
		return Result{StatusCode: 500, Error: err.Error()}
	}

	headers := http.Header{}
	headers.Set("Content-Type", "application/json")
	headers.Set("Environment", env)

	statusCode, respBody, err := doRequest(http.MethodPost, baseURL+"/v1/auth/apicode", headers, body)
	if err != nil {
		return Result{StatusCode: statusCode, Error: "inaccessible"}
	}
	if statusCode >= 400 {
		return apiError(statusCode, respBody)
	}

	var authResp struct {
		Token string `json:"token"`
	}
	if err := json.Unmarshal(respBody, &authResp); err != nil {
		return Result{StatusCode: statusCode, Error: "inaccessible"}
	}

	headers.Set("Authorization", "Bearer "+authResp.Token)
	s.baseURL = baseURL
	s.headers = headers
	s.initialized = true
	return Result{StatusCode: statusCode}
}

// GetEventPayload fetches the inbound event payload for actionID.
func (s *Session) GetEventPayload(actionID string) Result {
	if !s.initialized {
		return Result{StatusCode: 603, Error: "Init required"}
	}

	statusCode, respBody, err := doRequest(http.MethodGet, s.baseURL+"/v1/rtevent/"+actionID, s.headers, nil)
	if err != nil {
		return Result{StatusCode: statusCode, Error: "inaccessible"}
	}
	if statusCode >= 400 {
		return apiError(statusCode, respBody)
	}

	var resp struct {
		Payload any `json:"payload"`
	}
	if err := json.Unmarshal(respBody, &resp); err != nil {
		return Result{StatusCode: statusCode, Error: "inaccessible"}
	}
	return Result{StatusCode: statusCode, Payload: resp.Payload}
}

// PutStepPayload stores output for the current step.
func (s *Session) PutStepPayload(actionID, stepName string, payload any) Result {
	if !s.initialized {
		return Result{StatusCode: 603, Error: "Init required"}
	}

	body, err := json.Marshal(map[string]any{
		"actionId": actionID,
		"stepname": stepName,
		"payload":  payload,
	})
	if err != nil {
		return Result{StatusCode: 500, Error: err.Error()}
	}

	statusCode, respBody, err := doRequest(http.MethodPost, s.baseURL+"/v1/rtstep/payload", s.headers, body)
	if err != nil {
		return Result{StatusCode: statusCode, Error: "inaccessible"}
	}
	if statusCode >= 400 {
		return apiError(statusCode, respBody)
	}
	return Result{StatusCode: statusCode}
}

// GetStepPayload retrieves a prior step payload for actionID.
func (s *Session) GetStepPayload(actionID, stepName string) Result {
	if !s.initialized {
		return Result{StatusCode: 603, Error: "Init required"}
	}

	statusCode, respBody, err := doRequest(
		http.MethodGet,
		s.baseURL+"/v1/rtstep/payload/"+actionID+"/"+stepName,
		s.headers,
		nil,
	)
	if err != nil {
		return Result{StatusCode: statusCode, Error: "inaccessible"}
	}
	if statusCode >= 400 {
		return apiError(statusCode, respBody)
	}

	var resp struct {
		Payload any `json:"payload"`
	}
	if err := json.Unmarshal(respBody, &resp); err != nil {
		return Result{StatusCode: statusCode, Error: "inaccessible"}
	}
	return Result{StatusCode: statusCode, Payload: resp.Payload}
}

// GetKeystore fetches comma-separated keystore keys.
func (s *Session) GetKeystore(keylist string) Result {
	if !s.initialized {
		return Result{StatusCode: 603, Error: "Init required"}
	}

	keys := strings.ReplaceAll(keylist, " ", "")
	statusCode, respBody, err := doRequest(http.MethodGet, s.baseURL+"/v1/keystore/"+keys, s.headers, nil)
	if err != nil {
		return Result{StatusCode: statusCode, Error: "inaccessible"}
	}
	if statusCode >= 400 {
		return apiError(statusCode, respBody)
	}

	var answer map[string]any
	if err := json.Unmarshal(respBody, &answer); err != nil {
		return Result{StatusCode: statusCode, Error: "inaccessible"}
	}
	for _, key := range strings.Split(keys, ",") {
		if key == "" {
			continue
		}
		if _, ok := answer[key]; !ok {
			return Result{StatusCode: 605, Error: key + " not found"}
		}
	}
	return Result{StatusCode: statusCode, Answer: answer}
}

func doRequest(method, url string, headers http.Header, body []byte) (int, []byte, error) {
	var bodyReader io.Reader
	if body != nil {
		bodyReader = bytes.NewReader(body)
	}

	req, err := http.NewRequest(method, url, bodyReader)
	if err != nil {
		return 0, nil, err
	}
	req.Header = headers.Clone()

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		if resp != nil {
			return resp.StatusCode, nil, err
		}
		return 0, nil, err
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return resp.StatusCode, nil, err
	}
	return resp.StatusCode, respBody, nil
}

func apiError(statusCode int, respBody []byte) Result {
	var js any
	if err := json.Unmarshal(respBody, &js); err != nil {
		return Result{StatusCode: statusCode, Error: "inaccessible"}
	}
	return Result{StatusCode: statusCode, Error: js}
}

// MissingEnv returns a 601 result for the given variable list message.
func MissingEnv(vars string) Result {
	return Result{
		StatusCode: 601,
		Error:      fmt.Sprintf("Environment variables %s should be defined", vars),
	}
}
