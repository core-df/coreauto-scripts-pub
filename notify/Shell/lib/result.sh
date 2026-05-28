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

if [[ -n "${_NOTIFY_RESULT_LIB_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
_NOTIFY_RESULT_LIB_LOADED=1

NOTIFY_STATUS_CODE=""
NOTIFY_RESULT=""

_notify_set_result() {
  local status_code=$1
  local error=${2:-}
  local json_extra=${3:-}

  NOTIFY_STATUS_CODE=$status_code

  if [[ -n $json_extra ]]; then
    NOTIFY_RESULT=$(echo "$json_extra" | jq -c --argjson sc "$status_code" '. + {status_code: $sc}')
  elif [[ -n $error ]]; then
    NOTIFY_RESULT=$(jq -nc --argjson sc "$status_code" --arg err "$error" '{status_code: $sc, error: $err}')
  else
    NOTIFY_RESULT=$(jq -nc --argjson sc "$status_code" '{status_code: $sc}')
  fi
}

_notify_missing_env() {
  local vars=$1
  _notify_set_result 601 "Environment variables ${vars} should be defined"
}

_notify_transport_error() {
  local msg=${1:-inaccessible}
  _notify_set_result 0 "$msg"
}
