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

package result

import "fmt"

// Result mirrors queue client dict return values.
type Result struct {
	StatusCode int `json:"status_code"`
	Error      any `json:"error,omitempty"`
	Messages   any `json:"messages,omitempty"`
}

// MissingEnv returns a 601 result for the given variable list message.
func MissingEnv(vars string) Result {
	return Result{
		StatusCode: 601,
		Error:      fmt.Sprintf("Environment variables %s should be defined", vars),
	}
}

// TransportError returns a status 0 result for network or transport failures.
func TransportError(message string) Result {
	if message == "" {
		message = "inaccessible"
	}
	return Result{StatusCode: 0, Error: message}
}

// MQUnavailable returns a 500 result when IBM MQ client libraries are not available.
func MQUnavailable() Result {
	return Result{
		StatusCode: 500,
		Error:      "IBM MQ client libraries required (build with -tags ibmmq and install IBM MQ redistributable client; Go equivalent of Python pymqi)",
	}
}
