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
# Core Auto real-time step — full integration example (Shell port).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

Init
if [[ "$WBS_STATUS_CODE" != "200" ]]; then
  echo "$WBS_ERROR" >&2
  exit 1
fi

GetEventPayload
if [[ "$WBS_STATUS_CODE" != "200" ]]; then
  echo "$WBS_ERROR" >&2
  exit 1
fi

order_id=$(echo "$WBS_PAYLOAD" | jq -r '.orderId // .id // "unknown"')
ack_dir="${EXAMPLE_ACK_DIR:-/tmp/coreauto-example}"
mkdir -p "$ack_dir"
ack_path="$ack_dir/$order_id.json"

JsonStringify "$WBS_PAYLOAD"
if [[ "$TRANSFORM_STATUS_CODE" != "200" ]]; then
  echo "$TRANSFORM_RESULT" >&2
  exit 1
fi
text=$(echo "$TRANSFORM_RESULT" | jq -r '.text')

LocalWrite "$ack_path" "$text"
if [[ "$FILE_STATUS_CODE" != "200" ]]; then
  echo "$FILE_RESULT" >&2
  exit 1
fi

topic="${EXAMPLE_KAFKA_TOPIC:-orders.enriched}"
Produce "$topic" "$text" || true

output_json=$(jq -nc --arg id "$order_id" --arg p "$ack_path" '{orderId: $id, ackPath: $p}')
PutStepPayload "$output_json"
if [[ "$WBS_STATUS_CODE" != "200" ]]; then
  echo "$WBS_ERROR" >&2
  exit 1
fi

jq -nc --argjson out "$output_json" '{status_code: 200, result: $out}'
