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
// Generic HTTP client helpers for Core Auto step scripts (non-Collector REST calls).

package httpclient

import (
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/core-df/coreauto-scripts-pub/http/Go/internal/result"
)

const requestTimeout = 60 * time.Second

var httpClient = &http.Client{Timeout: requestTimeout} // swapped in unit tests

// Get performs an HTTP GET request.
func Get(urlStr string, headers map[string]string, params map[string]string) result.Result {
	if len(params) > 0 {
		u, err := url.Parse(urlStr)
		if err != nil {
			return result.TransportError(err.Error())
		}
		q := u.Query()
		for k, v := range params {
			q.Set(k, v)
		}
		u.RawQuery = q.Encode()
		urlStr = u.String()
	}
	return doRequest(http.MethodGet, urlStr, headers, nil)
}

// Post performs an HTTP POST request with optional JSON or raw body.
func Post(urlStr string, jsonBody any, data []byte, headers map[string]string) result.Result {
	hdrs := cloneHeaders(headers)
	var body []byte
	if jsonBody != nil {
		if _, ok := hdrs["Content-Type"]; !ok {
			hdrs["Content-Type"] = "application/json"
		}
		b, err := json.Marshal(jsonBody)
		if err != nil {
			return result.Result{StatusCode: 500, Error: err.Error()}
		}
		body = b
	} else if data != nil {
		body = data
	}
	return doRequest(http.MethodPost, urlStr, hdrs, body)
}

// Put performs an HTTP PUT request with optional JSON body.
func Put(urlStr string, jsonBody any, headers map[string]string) result.Result {
	hdrs := cloneHeaders(headers)
	var body []byte
	if jsonBody != nil {
		if _, ok := hdrs["Content-Type"]; !ok {
			hdrs["Content-Type"] = "application/json"
		}
		b, err := json.Marshal(jsonBody)
		if err != nil {
			return result.Result{StatusCode: 500, Error: err.Error()}
		}
		body = b
	}
	return doRequest(http.MethodPut, urlStr, hdrs, body)
}

// Delete performs an HTTP DELETE request.
func Delete(urlStr string, headers map[string]string) result.Result {
	return doRequest(http.MethodDelete, urlStr, headers, nil)
}

func doRequest(method, urlStr string, headers map[string]string, body []byte) result.Result {
	var bodyReader io.Reader
	if body != nil {
		bodyReader = bytes.NewReader(body)
	}

	req, err := http.NewRequest(method, urlStr, bodyReader)
	if err != nil {
		return result.TransportError(err.Error())
	}
	for k, v := range headers {
		req.Header.Set(k, v)
	}

	resp, err := httpClient.Do(req)
	if err != nil {
		return result.TransportError(err.Error())
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		return result.TransportError(err.Error())
	}

	parsed := parseBody(respBody)
	if resp.StatusCode >= 400 {
		errVal := any(parsed)
		if parsed == nil {
			errVal = "inaccessible"
		}
		return result.Result{StatusCode: resp.StatusCode, Error: errVal}
	}
	return result.Result{StatusCode: resp.StatusCode, Body: parsed}
}

func parseBody(data []byte) any {
	if len(data) == 0 {
		return nil
	}
	var js any
	if err := json.Unmarshal(data, &js); err == nil {
		return js
	}
	return strings.TrimSpace(string(data))
}

func cloneHeaders(headers map[string]string) map[string]string {
	if headers == nil {
		return map[string]string{}
	}
	out := make(map[string]string, len(headers))
	for k, v := range headers {
		out[k] = v
	}
	return out
}
