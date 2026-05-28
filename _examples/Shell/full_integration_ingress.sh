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
# Kafka ingress bridge — Shell port.
set -euo pipefail
EX_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$EX_ROOT/queues/ingress/Shell/ingress.sh"
source "$EX_ROOT/queues/kafka/Shell/kafkaclient.sh"

topic="${1:-${EXAMPLE_KAFKA_TOPIC:-orders.inbound}}"
echo "Bridging Kafka topic $topic → Core Auto (CA_EVENT_NAME)" >&2

while true; do
  RunBridge Consume "$topic" 30 10
  if [[ "$INGRESS_STATUS_CODE" -ge 400 || "$INGRESS_STATUS_CODE" == "0" ]]; then
    echo "$INGRESS_RESULT" >&2
    sleep 5
    continue
  fi
  if echo "$INGRESS_RESULT" | jq -e '.forwarded | length > 0' >/dev/null 2>&1; then
    echo "$INGRESS_RESULT"
  fi
done
