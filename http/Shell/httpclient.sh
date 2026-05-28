#!/usr/bin/env bash
# Copyright Core DF
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Generic HTTP client helpers for Core Auto step scripts (non-Collector REST calls).

_HTTPCLIENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=lib/result.sh
source "${_HTTPCLIENT_DIR}/lib/result.sh"

_http_curl() {
  local method=$1 url=$2 data=${3:-} headers_json=${4:-{}}
  local -a args=(-s -S -w $'\n%{http_code}' -X "$method")

  local key val
  while IFS= read -r key; do
    val=$(echo "$headers_json" | jq -r --arg k "$key" '.[$k] // empty')
    [[ -n $val && $val != null ]] && args+=(-H "${key}: ${val}")
  done < <(echo "$headers_json" | jq -r 'keys[]? // empty')

  if [[ -n $data ]]; then
    args+=(-d "$data")
  fi

  local raw=""
  if ! raw=$(curl "${args[@]}" "$url"); then
    _HTTP_HTTP_CODE=0
    _HTTP_RESP_BODY=""
    return 1
  fi

  _HTTP_HTTP_CODE=${raw##*$'\n'}
  _HTTP_RESP_BODY=${raw%$'\n'*}
  return 0
}

_http_request() {
  local method=$1 url=$2 headers_json=${3:-{}} data=${4:-}

  if ! _http_curl "$method" "$url" "$data" "$headers_json"; then
    _http_transport_error
    return 0
  fi

  local http_code=$_HTTP_HTTP_CODE body=$_HTTP_RESP_BODY

  if [[ $http_code -ge 400 ]]; then
    if echo "$body" | jq -e . >/dev/null 2>&1; then
      _http_set_result "$http_code" "$(echo "$body" | jq -c .)"
    else
      _http_set_result "$http_code" "inaccessible"
    fi
    return 0
  fi

  if echo "$body" | jq -e . >/dev/null 2>&1; then
    _http_set_result "$http_code" "" "$(echo "$body" | jq -c .)"
  elif [[ -z $body ]]; then
    _http_set_result "$http_code"
  else
    _http_set_result "$http_code" "" "$body"
  fi
}

Get() {
  local url=$1 headers_json=${2:-{}}
  _http_request GET "$url" "$headers_json"
}

Post() {
  local url=$1 json_body=${2:-} data=${3:-} headers_json=${4:-{}}
  if [[ -n $json_body ]]; then
    if ! echo "$headers_json" | jq -e 'has("Content-Type")' >/dev/null 2>&1; then
      headers_json=$(echo "$headers_json" | jq -c '. + {"Content-Type": "application/json"}')
    fi
    _http_request POST "$url" "$headers_json" "$json_body"
  else
    _http_request POST "$url" "$headers_json" "$data"
  fi
}

Put() {
  local url=$1 json_body=${2:-} headers_json=${3:-{}}
  if [[ -n $json_body ]]; then
    if ! echo "$headers_json" | jq -e 'has("Content-Type")' >/dev/null 2>&1; then
      headers_json=$(echo "$headers_json" | jq -c '. + {"Content-Type": "application/json"}')
    fi
    _http_request PUT "$url" "$headers_json" "$json_body"
  else
    _http_request PUT "$url" "$headers_json"
  fi
}

Delete() {
  local url=$1 headers_json=${2:-{}}
  _http_request DELETE "$url" "$headers_json"
}
