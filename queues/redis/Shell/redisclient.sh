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
# Redis list helpers for Core Auto. Push from step scripts; Pop for ingress bridges.

_REDISCLIENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=lib/result.sh
source "${_REDISCLIENT_DIR}/lib/result.sh"

_encode_value() {
  local value=$1
  if echo "$value" | jq -e . >/dev/null 2>&1; then echo "$value" | jq -c .; else printf '%s' "$value"; fi
}

_redis_cli() {
  if [[ -n ${REDIS_URL:-} ]]; then
    redis-cli -u "$REDIS_URL" "$@"
  else
    local host=${REDIS_HOST:-} port=${REDIS_PORT:-6379} db=${REDIS_DB:-0}
    [[ -z $host ]] && return 1
    if [[ -n ${REDIS_PASSWORD:-} ]]; then
      redis-cli -h "$host" -p "$port" -n "$db" -a "$REDIS_PASSWORD" "$@"
    else
      redis-cli -h "$host" -p "$port" -n "$db" "$@"
    fi
  fi
}

Init() {
  if [[ -z ${REDIS_URL:-} && -z ${REDIS_HOST:-} ]]; then
    _redis_missing_env "REDIS_URL or REDIS_HOST"
    return 0
  fi
  _redis_set_result 200
}

Push() {
  local queue=$1 value=$2 payload err
  if [[ -z ${REDIS_URL:-} && -z ${REDIS_HOST:-} ]]; then
    _redis_missing_env "REDIS_URL or REDIS_HOST"
    return 0
  fi
  payload=$(_encode_value "$value")
  if ! err=$(_redis_cli LPUSH "$queue" "$payload" 2>&1); then
    _redis_transport_error "$err"
    return 0
  fi
  _redis_set_result 200
}

Pop() {
  local queue=$1 timeout_sec=${2:-30} max_messages=${3:-1}
  local messages='[]' i=0 wait item val
  if [[ -z ${REDIS_URL:-} && -z ${REDIS_HOST:-} ]]; then
    _redis_missing_env "REDIS_URL or REDIS_HOST"
    return 0
  fi
  while [[ $i -lt $max_messages ]]; do
    wait=$timeout_sec
    [[ $i -gt 0 ]] && wait=1
    item=$(_redis_cli BRPOP "$queue" "$wait" 2>/dev/null | tail -1 || true)
    [[ -z $item ]] && break
    if val=$(echo "$item" | jq -c . 2>/dev/null); then :; else val=$(jq -nc --arg v "$item" '$v'); fi
    messages=$(echo "$messages" | jq -c --argjson v "$val" --arg q "$queue" '. + [{queue: $q, value: $v}]')
    i=$((i + 1))
  done
  _redis_set_result 200 "" "$(jq -nc --argjson m "$messages" '{messages: $m}')"
  QUEUE_RESULT=$REDIS_RESULT
}
