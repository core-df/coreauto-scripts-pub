# Copyright Core DF

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
# Shared HTTP helpers for the Core Auto Collector (cawbs) shell client.

if [[ -n "${_WBS_LIB_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
_WBS_LIB_LOADED=1

wbs_iniflag=false
wbs_url=""
wbs_env=""
wbs_token=""

WBS_STATUS_CODE=""
WBS_ERROR=""
WBS_PAYLOAD=""
WBS_ANSWER=""
WBS_RESULT=""

_wbs_trim_url() {
  local u=$1
  u="${u#"${u%%[![:space:]/]*}"}"
  u="${u%"${u##*[![:space:]/]}"}"
  printf '%s' "$u"
}

_wbs_set_result() {
  local status_code=$1
  local error=${2:-}
  local payload=${3:-}
  local answer=${4:-}

  WBS_STATUS_CODE=$status_code
  WBS_ERROR=$error
  WBS_PAYLOAD=$payload
  WBS_ANSWER=$answer

  if [[ -n $answer ]]; then
    WBS_RESULT=$(jq -nc \
      --argjson sc "$status_code" \
      --argjson ans "$answer" \
      '{status_code: $sc, answer: $ans}')
  elif [[ -n $payload ]]; then
    WBS_RESULT=$(jq -nc \
      --argjson sc "$status_code" \
      --argjson pl "$payload" \
      '{status_code: $sc, payload: $pl}')
  elif [[ -n $error ]]; then
    if [[ $error == \{* ]] || [[ $error == \[* ]]; then
      WBS_RESULT=$(jq -nc \
        --argjson sc "$status_code" \
        --argjson err "$error" \
        '{status_code: $sc, error: $err}')
    else
      WBS_RESULT=$(jq -nc \
        --argjson sc "$status_code" \
        --arg err "$error" \
        '{status_code: $sc, error: $err}')
    fi
  else
    WBS_RESULT=$(jq -nc --argjson sc "$status_code" '{status_code: $sc}')
  fi
}

_wbs_curl() {
  local method=$1 url=$2 data=${3:-}
  local -a args=(-s -S -w $'\n%{http_code}' -X "$method")
  args+=(-H "Content-Type: application/json" -H "Environment: ${wbs_env}")
  if [[ -n $wbs_token ]]; then
    args+=(-H "Authorization: Bearer ${wbs_token}")
  fi
  if [[ -n $data ]]; then
    args+=(-d "$data")
  fi

  local raw=""
  if ! raw=$(curl "${args[@]}" "$url"); then
    _WBS_HTTP_CODE=0
    _WBS_BODY=""
    return 1
  fi

  _WBS_HTTP_CODE=${raw##*$'\n'}
  _WBS_BODY=${raw%$'\n'*}
  return 0
}

_wbs_handle_response() {
  local http_code=$1 body=$2

  if [[ $http_code -ge 400 ]]; then
    if echo "$body" | jq -e . >/dev/null 2>&1; then
      _wbs_set_result "$http_code" "$(echo "$body" | jq -c .)"
    else
      _wbs_set_result "$http_code" "inaccessible"
    fi
    return 0
  fi

  if ! echo "$body" | jq -e . >/dev/null 2>&1; then
    _wbs_set_result "$http_code" "inaccessible"
    return 0
  fi

  _WBS_HTTP_CODE=$http_code
  _WBS_BODY=$body
  return 0
}

_wbs_require_init() {
  if [[ $wbs_iniflag != true ]]; then
    _wbs_set_result 603 "Init required"
    return 1
  fi
  return 0
}

_wbs_authenticate() {
  local env=$1 access_code=$2 base_url=$3

  if [[ $wbs_iniflag == true ]]; then
    _wbs_set_result 602 "init already called"
    return 0
  fi

  wbs_env=$env
  wbs_url=$(_wbs_trim_url "$base_url")

  local todo
  todo=$(jq -nc --arg code "$access_code" '{apiCode: $code}')

  if ! _wbs_curl POST "${wbs_url}/v1/auth/apicode" "$todo"; then
    _wbs_set_result 0 "inaccessible"
    return 0
  fi

  if [[ $_WBS_HTTP_CODE -ge 400 ]]; then
    _wbs_handle_response "$_WBS_HTTP_CODE" "$_WBS_BODY"
    return 0
  fi

  wbs_token=$(echo "$_WBS_BODY" | jq -r .token)
  if [[ -z $wbs_token || $wbs_token == null ]]; then
    _wbs_set_result "$_WBS_HTTP_CODE" "inaccessible"
    return 0
  fi

  wbs_iniflag=true
  _wbs_set_result "$_WBS_HTTP_CODE"
}

_wbs_get_event_payload() {
  local action_id=$1

  _wbs_require_init || return 0

  if ! _wbs_curl GET "${wbs_url}/v1/rtevent/${action_id}"; then
    _wbs_set_result 0 "inaccessible"
    return 0
  fi

  if [[ $_WBS_HTTP_CODE -ge 400 ]]; then
    _wbs_handle_response "$_WBS_HTTP_CODE" "$_WBS_BODY"
    return 0
  fi

  local payload
  payload=$(echo "$_WBS_BODY" | jq -c .payload)
  _wbs_set_result "$_WBS_HTTP_CODE" "" "$payload"
}

_wbs_put_step_payload() {
  local action_id=$1 step_name=$2 payload=$3

  _wbs_require_init || return 0

  local todo
  todo=$(jq -nc \
    --arg aid "$action_id" \
    --arg sn "$step_name" \
    --argjson pl "$payload" \
    '{actionId: $aid, stepname: $sn, payload: $pl}')

  if ! _wbs_curl POST "${wbs_url}/v1/rtstep/payload" "$todo"; then
    _wbs_set_result 0 "inaccessible"
    return 0
  fi

  if [[ $_WBS_HTTP_CODE -ge 400 ]]; then
    _wbs_handle_response "$_WBS_HTTP_CODE" "$_WBS_BODY"
    return 0
  fi

  _wbs_set_result "$_WBS_HTTP_CODE"
}

_wbs_get_step_payload() {
  local action_id=$1 step_name=$2

  _wbs_require_init || return 0

  if ! _wbs_curl GET "${wbs_url}/v1/rtstep/payload/${action_id}/${step_name}"; then
    _wbs_set_result 0 "inaccessible"
    return 0
  fi

  if [[ $_WBS_HTTP_CODE -ge 400 ]]; then
    _wbs_handle_response "$_WBS_HTTP_CODE" "$_WBS_BODY"
    return 0
  fi

  local payload
  payload=$(echo "$_WBS_BODY" | jq -c .payload)
  _wbs_set_result "$_WBS_HTTP_CODE" "" "$payload"
}

_wbs_get_keystore() {
  local keylist=$1
  local keys=${keylist// /}

  _wbs_require_init || return 0

  if ! _wbs_curl GET "${wbs_url}/v1/keystore/${keys}"; then
    _wbs_set_result 0 "inaccessible"
    return 0
  fi

  if [[ $_WBS_HTTP_CODE -ge 400 ]]; then
    _wbs_handle_response "$_WBS_HTTP_CODE" "$_WBS_BODY"
    return 0
  fi

  local answer
  answer=$(echo "$_WBS_BODY" | jq -c .)

  local IFS=',' key
  for key in $keys; do
    [[ -z $key ]] && continue
    if ! echo "$answer" | jq -e --arg k "$key" 'has($k)' >/dev/null 2>&1; then
      _wbs_set_result 605 "${key} not found"
      return 0
    fi
  done

  _wbs_set_result "$_WBS_HTTP_CODE" "" "" "$answer"
}

_wbs_post_event() {
  local event_name=$1 payload=$2 event_source=${3:-}

  _wbs_require_init || return 0

  local todo
  if [[ -n $event_source ]]; then
    todo=$(jq -nc \
      --arg en "$event_name" \
      --argjson pl "$payload" \
      --arg es "$event_source" \
      '{eventName: $en, payload: $pl, eventSource: $es}')
  else
    todo=$(jq -nc \
      --arg en "$event_name" \
      --argjson pl "$payload" \
      '{eventName: $en, payload: $pl}')
  fi

  if ! _wbs_curl POST "${wbs_url}/v1/rtevent" "$todo"; then
    _wbs_set_result 0 "inaccessible"
    return 0
  fi

  if [[ $_WBS_HTTP_CODE -ge 400 ]]; then
    _wbs_handle_response "$_WBS_HTTP_CODE" "$_WBS_BODY"
    return 0
  fi

  WBS_STATUS_CODE=$_WBS_HTTP_CODE
  WBS_ERROR=""
  WBS_RESULT=$(echo "$_WBS_BODY" | jq -c \
    --argjson sc "$_WBS_HTTP_CODE" \
    '{status_code: $sc, eventId: .eventId, actionId: .actionId, createdAt: .createdAt}')
}

_wbs_get_event_status() {
  local action_id=$1

  _wbs_require_init || return 0

  if ! _wbs_curl GET "${wbs_url}/v1/rtevent/status/${action_id}"; then
    _wbs_set_result 0 "inaccessible"
    return 0
  fi

  if [[ $_WBS_HTTP_CODE -ge 400 ]]; then
    _wbs_handle_response "$_WBS_HTTP_CODE" "$_WBS_BODY"
    return 0
  fi

  WBS_STATUS_CODE=$_WBS_HTTP_CODE
  WBS_ERROR=""
  WBS_RESULT=$(echo "$_WBS_BODY" | jq -c \
    --argjson sc "$_WBS_HTTP_CODE" \
    '{status_code: $sc, status: .}')
}

_wbs_get_event_list() {
  _wbs_require_init || return 0

  if ! _wbs_curl GET "${wbs_url}/v1/rtevent/list"; then
    _wbs_set_result 0 "inaccessible"
    return 0
  fi

  if [[ $_WBS_HTTP_CODE -ge 400 ]]; then
    _wbs_handle_response "$_WBS_HTTP_CODE" "$_WBS_BODY"
    return 0
  fi

  WBS_STATUS_CODE=$_WBS_HTTP_CODE
  WBS_ERROR=""
  WBS_RESULT=$(echo "$_WBS_BODY" | jq -c \
    --argjson sc "$_WBS_HTTP_CODE" \
    '{status_code: $sc, events: .}')
}

_wbs_submit_flag() {
  local name=$1 system_name=$2 source_system_name=$3 date=$4

  _wbs_require_init || return 0

  local todo
  todo=$(jq -nc \
    --arg n "$name" \
    --arg sn "$system_name" \
    --arg ssn "$source_system_name" \
    --arg d "$date" \
    '{name: $n, systemName: $sn, sourceSystemName: $ssn, date: $d}')

  if ! _wbs_curl POST "${wbs_url}/v1/flag" "$todo"; then
    _wbs_set_result 0 "inaccessible"
    return 0
  fi

  if [[ $_WBS_HTTP_CODE -ge 400 ]]; then
    _wbs_handle_response "$_WBS_HTTP_CODE" "$_WBS_BODY"
    return 0
  fi

  WBS_STATUS_CODE=$_WBS_HTTP_CODE
  WBS_ERROR=""
  WBS_RESULT=$(echo "$_WBS_BODY" | jq -c \
    --argjson sc "$_WBS_HTTP_CODE" \
    '{status_code: $sc, flagStatus: .status}')
}
