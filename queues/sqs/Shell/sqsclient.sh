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
# Amazon SQS helpers for Core Auto. Send from step scripts; Receive for ingress bridges.

_SQSCLIENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=lib/result.sh
source "${_SQSCLIENT_DIR}/lib/result.sh"

_encode_value() {
  local value=$1
  if echo "$value" | jq -e . >/dev/null 2>&1; then echo "$value" | jq -c .; else printf '%s' "$value"; fi
}

_sqs_endpoint_args() {
  if [[ -n ${SQS_ENDPOINT_URL:-} ]]; then echo "--endpoint-url" "${SQS_ENDPOINT_URL}"; fi
}

Init() {
  if [[ -z ${AWS_ACCESS_KEY_ID:-} && -z ${AWS_PROFILE:-} ]]; then
    _sqs_missing_env "AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY or AWS_PROFILE"
    return 0
  fi
  if [[ -z ${SQS_QUEUE_URL:-} ]]; then
    _sqs_missing_env "SQS_QUEUE_URL (or pass queue_url per call)"
    return 0
  fi
  _sqs_set_result 200
}

Send() {
  local value=$1 queue_url=${2:-${SQS_QUEUE_URL:-}}
  local body err mid
  [[ -z $queue_url ]] && { _sqs_missing_env "SQS_QUEUE_URL"; return 0; }
  body=$(_encode_value "$value")
  # shellcheck disable=SC2046
  if ! err=$(aws sqs send-message --queue-url "$queue_url" --message-body "$body" $( _sqs_endpoint_args ) 2>&1); then
    _sqs_transport_error "$err"
    return 0
  fi
  mid=$(echo "$err" | jq -r .MessageId 2>/dev/null || true)
  _sqs_set_result 200 "" "$(jq -nc --arg m "$mid" '{message_id: $m}')"
}

Receive() {
  local queue_url=${1:-${SQS_QUEUE_URL:-}} max_messages=${2:-1} wait_time=${3:-10} delete=${4:-true}
  local out messages
  [[ -z $queue_url ]] && { _sqs_missing_env "SQS_QUEUE_URL"; return 0; }
  # shellcheck disable=SC2046
  if ! out=$(aws sqs receive-message --queue-url "$queue_url" --max-number-of-messages "$max_messages" --wait-time-seconds "$wait_time" $( _sqs_endpoint_args ) 2>&1); then
    _sqs_transport_error "$out"
    return 0
  fi
  messages=$(echo "$out" | jq -c '[.Messages[]? | {message_id: .MessageId, receipt_handle: .ReceiptHandle, value: (.Body | try fromjson catch .)}] | {messages: .}')
  if [[ "$delete" == true ]]; then
    echo "$out" | jq -r '.Messages[]?.ReceiptHandle // empty' | while read -r rh; do
      [[ -n $rh ]] && aws sqs delete-message --queue-url "$queue_url" --receipt-handle "$rh" $( _sqs_endpoint_args ) >/dev/null 2>&1 || true
    done
  fi
  _sqs_set_result 200 "" "$messages"
  QUEUE_RESULT=$SQS_RESULT
}
