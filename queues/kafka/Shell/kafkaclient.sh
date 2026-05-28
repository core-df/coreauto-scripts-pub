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
# Kafka helpers for Core Auto. Produce from step scripts; Consume for ingress bridges.

_KAFKACLIENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "${_KAFKACLIENT_DIR}/lib/result.sh"


_encode_value() {
  local value=$1
  if echo "$value" | jq -e . >/dev/null 2>&1; then
    echo "$value" | jq -c .
  else
    printf '%s' "$value"
  fi
}


Init() {
  if [[ -z ${KAFKA_BOOTSTRAP_SERVERS:-} ]]; then
    _kafka_missing_env "KAFKA_BOOTSTRAP_SERVERS"
    return 0
  fi
  if ! command -v kafka-console-producer.sh >/dev/null 2>&1 && ! command -v kafka-console-producer >/dev/null 2>&1; then
    _kafka_set_result 500 "kafka-console-producer required (Apache Kafka distribution)"
    return 0
  fi
  _kafka_set_result 200
}

_producer_cmd() {
  if command -v kafka-console-producer.sh >/dev/null 2>&1; then
    echo kafka-console-producer.sh
  else
    echo kafka-console-producer
  fi
}

_consumer_cmd() {
  if command -v kafka-console-consumer.sh >/dev/null 2>&1; then
    echo kafka-console-consumer.sh
  else
    echo kafka-console-consumer
  fi
}

Produce() {
  local topic=$1 value=$2 key=${3:-}
  if [[ -z ${KAFKA_BOOTSTRAP_SERVERS:-} ]]; then
    _kafka_missing_env "KAFKA_BOOTSTRAP_SERVERS"
    return 0
  fi
  local payload producer err
  payload=$(_encode_value "$value")
  producer=$(_producer_cmd)
  if ! err=$(printf '%s\n' "$payload" | "$producer" --bootstrap-server "$KAFKA_BOOTSTRAP_SERVERS" --topic "$topic" 2>&1); then
    _kafka_transport_error "$err"
    return 0
  fi
  _kafka_set_result 200
}

Consume() {
  local topic=$1 timeout_sec=${2:-30} max_messages=${3:-1} group_id=${4:-${KAFKA_GROUP_ID:-coreauto-step}}
  if [[ -z ${KAFKA_BOOTSTRAP_SERVERS:-} ]]; then
    _kafka_missing_env "KAFKA_BOOTSTRAP_SERVERS"
    return 0
  fi
  local consumer out err
  consumer=$(_consumer_cmd)
  if ! out=$(timeout "$timeout_sec" "$consumer" \
    --bootstrap-server "$KAFKA_BOOTSTRAP_SERVERS" \
    --topic "$topic" \
    --group "$group_id" \
    --from-beginning \
    --max-messages "$max_messages" 2>&1); then
    [[ -z "$out" ]] && out="consume timeout or error"
    _kafka_transport_error "$out"
    return 0
  fi
  local messages
  messages=$(echo "$out" | jq -R . | jq -s -c --arg t "$topic" '[.[] | {topic: $t, value: (try fromjson catch .)}] | {messages: .}')
  _kafka_set_result 200 "" "$messages"
  QUEUE_RESULT=$KAFKA_RESULT
}
