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
# Azure Service Bus helpers for Core Auto. Send from step scripts; Receive for ingress bridges.

_SERVICEBUSCLIENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=lib/result.sh
source "${_SERVICEBUSCLIENT_DIR}/lib/result.sh"

_encode_value() {
  local value=$1
  if echo "$value" | jq -e . >/dev/null 2>&1; then echo "$value" | jq -c .; else printf '%s' "$value"; fi
}

Init() {
  if [[ -z ${SERVICE_BUS_CONNECTION_STRING:-} ]]; then
    _servicebus_missing_env "SERVICE_BUS_CONNECTION_STRING"
    return 0
  fi
  if [[ -z ${SERVICE_BUS_QUEUE_NAME:-} ]]; then
    _servicebus_missing_env "SERVICE_BUS_QUEUE_NAME (or pass queue per call)"
    return 0
  fi
  _servicebus_set_result 200
}

Send() {
  local value=$1 queue=${2:-${SERVICE_BUS_QUEUE_NAME:-}}
  local payload err
  [[ -z ${SERVICE_BUS_CONNECTION_STRING:-} ]] && { _servicebus_missing_env "SERVICE_BUS_CONNECTION_STRING"; return 0; }
  [[ -z $queue ]] && { _servicebus_missing_env "SERVICE_BUS_QUEUE_NAME"; return 0; }
  payload=$(_encode_value "$value")
  if command -v az >/dev/null 2>&1; then
    if ! err=$(az servicebus queue message send \
      --connection-string "$SERVICE_BUS_CONNECTION_STRING" \
      --queue-name "$queue" \
      --body "$payload" 2>&1); then
      _servicebus_transport_error "$err"
      return 0
    fi
  elif ! err=$(python3 - "$queue" <<PY 2>&1
import os, sys
try:
    from azure.servicebus import ServiceBusClient, ServiceBusMessage
except ImportError:
    print("azure-servicebus package or az CLI required", file=sys.stderr); sys.exit(1)
conn = os.environ["SERVICE_BUS_CONNECTION_STRING"]
queue = sys.argv[1]
body = sys.stdin.read().encode()
with ServiceBusClient.from_connection_string(conn) as client:
    sender = client.get_queue_sender(queue_name=queue)
    with sender:
        sender.send_messages(ServiceBusMessage(body=body))
PY
<<< "$payload"); then
    _servicebus_transport_error "$err"
    return 0
  fi
  _servicebus_set_result 200
}

Receive() {
  local queue=${1:-${SERVICE_BUS_QUEUE_NAME:-}} timeout_sec=${2:-30} max_messages=${3:-1}
  local out
  [[ -z ${SERVICE_BUS_CONNECTION_STRING:-} ]] && { _servicebus_missing_env "SERVICE_BUS_CONNECTION_STRING"; return 0; }
  [[ -z $queue ]] && { _servicebus_missing_env "SERVICE_BUS_QUEUE_NAME"; return 0; }
  if ! out=$(python3 - "$queue" "$timeout_sec" "$max_messages" <<'PY' 2>&1
import json, os, sys
try:
    from azure.servicebus import ServiceBusClient
except ImportError:
    print("azure-servicebus package required for Receive", file=sys.stderr); sys.exit(1)
conn = os.environ["SERVICE_BUS_CONNECTION_STRING"]
queue, timeout_sec, max_messages = sys.argv[1], int(float(sys.argv[2])), int(sys.argv[3])
messages = []
with ServiceBusClient.from_connection_string(conn) as client:
    receiver = client.get_queue_receiver(queue_name=queue)
    with receiver:
        batch = receiver.receive_messages(max_message_count=max(1, max_messages), max_wait_time=timeout_sec)
        for msg in batch:
            raw = msg.body if isinstance(msg.body, bytes) else b"".join(msg.body)
            try:
                val = json.loads(raw.decode())
            except Exception:
                val = raw.decode(errors="replace")
            messages.append({"queue": queue, "message_id": str(msg.message_id) if msg.message_id else None, "value": val})
            receiver.complete_message(msg)
print(json.dumps({"messages": messages}))
PY
); then
    _servicebus_transport_error "$out"
    return 0
  fi
  _servicebus_set_result 200 "" "$out"
  QUEUE_RESULT=$SERVICEBUS_RESULT
}
