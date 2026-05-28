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
# Queue ingress bridge — consume from a queue and submit Core Auto events via cawbsingress.

_INGRESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=lib/result.sh
source "${_INGRESS_DIR}/lib/result.sh"

_CAWBSINGRESS_SH="${CAWBS_SHELL:-${_INGRESS_DIR}/../../../cawbs/Shell/cawbsingress.sh}"
# shellcheck source=/dev/null
source "${_CAWBSINGRESS_SH}"

TriggerEvent() {
  local payload=$1 event_name=${2:-${CA_EVENT_NAME:-}} event_source=${3:-${CA_EVENT_SOURCE:-}}
  if [[ -z $event_name ]]; then
    _ingress_missing_env "CA_EVENT_NAME (or pass event_name)"
    return 0
  fi
  Init
  if [[ "$WBS_STATUS_CODE" != "200" ]]; then
    _ingress_set_result "$WBS_STATUS_CODE" "$WBS_ERROR"
    return 0
  fi
  if [[ -n $event_source ]]; then
    PostEvent "$event_name" "$payload" "$event_source"
  else
    PostEvent "$event_name" "$payload"
  fi
  INGRESS_STATUS_CODE=$WBS_STATUS_CODE
  INGRESS_RESULT=$WBS_RESULT
}

ForwardMessages() {
  local consume_result=$1
  local sc
  sc=$(echo "$consume_result" | jq -r .status_code)
  if [[ "$sc" != "200" ]]; then
    INGRESS_STATUS_CODE=$sc
    INGRESS_RESULT=$consume_result
    return 0
  fi
  local forwarded='[]' msg value result
  while IFS= read -r msg; do
    [[ -z $msg ]] && continue
    value=$(echo "$msg" | jq -c '.value // .')
    TriggerEvent "$value"
    if [[ "$INGRESS_STATUS_CODE" -ge 400 || "$INGRESS_STATUS_CODE" == "0" ]]; then
      return 0
    fi
    forwarded=$(echo "$forwarded" | jq -c \
      --argjson r "$INGRESS_RESULT" \
      '. + [{actionId: $r.actionId, eventId: $r.eventId}]')
  done < <(echo "$consume_result" | jq -c '.messages[]?')
  _ingress_set_result 200 "" "$(jq -nc --argjson f "$forwarded" '{forwarded: $f}')"
}

RunBridge() {
  local fn=$1
  shift
  $fn "$@"
  ForwardMessages "${QUEUE_RESULT:-{}}"
}
