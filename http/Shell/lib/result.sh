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

if [[ -n "${_HTTP_RESULT_LIB_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
_HTTP_RESULT_LIB_LOADED=1

HTTP_STATUS_CODE=""
HTTP_BODY=""
HTTP_RESULT=""

_http_set_result() {
  local status_code=$1
  local error=${2:-}
  local body=${3:-}

  HTTP_STATUS_CODE=$status_code
  HTTP_BODY=$body

  if [[ -n $body ]]; then
    if [[ $body == \{* ]] || [[ $body == \[* ]]; then
      HTTP_RESULT=$(jq -nc \
        --argjson sc "$status_code" \
        --argjson b "$body" \
        '{status_code: $sc, body: $b}')
    else
      HTTP_RESULT=$(jq -nc \
        --argjson sc "$status_code" \
        --arg b "$body" \
        '{status_code: $sc, body: $b}')
    fi
  elif [[ -n $error ]]; then
    if [[ $error == \{* ]] || [[ $error == \[* ]]; then
      HTTP_RESULT=$(jq -nc \
        --argjson sc "$status_code" \
        --argjson err "$error" \
        '{status_code: $sc, error: $err}')
    else
      HTTP_RESULT=$(jq -nc \
        --argjson sc "$status_code" \
        --arg err "$error" \
        '{status_code: $sc, error: $err}')
    fi
  else
    HTTP_RESULT=$(jq -nc --argjson sc "$status_code" '{status_code: $sc}')
  fi
}

_http_missing_env() {
  local vars=$1
  _http_set_result 601 "Environment variables ${vars} should be defined"
}

_http_transport_error() {
  local msg=${1:-inaccessible}
  _http_set_result 0 "$msg"
}
