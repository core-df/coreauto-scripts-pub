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

if [[ -n "${_FILE_RESULT_LIB_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
_FILE_RESULT_LIB_LOADED=1

FILE_STATUS_CODE=""
FILE_RESULT=""

_file_set_result() {
  local status_code=$1
  local error=${2:-}
  local json_extra=${3:-}

  FILE_STATUS_CODE=$status_code

  if [[ -n $json_extra ]]; then
    FILE_RESULT=$(echo "$json_extra" | jq -c --argjson sc "$status_code" '. + {status_code: $sc}')
  elif [[ -n $error ]]; then
    FILE_RESULT=$(jq -nc --argjson sc "$status_code" --arg err "$error" '{status_code: $sc, error: $err}')
  else
    FILE_RESULT=$(jq -nc --argjson sc "$status_code" '{status_code: $sc}')
  fi
}

_file_missing_env() {
  local vars=$1
  _file_set_result 601 "Environment variables ${vars} should be defined"
}

_file_transport_error() {
  local msg=${1:-inaccessible}
  _file_set_result 0 "$msg"
}
