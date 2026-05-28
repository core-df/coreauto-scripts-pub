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
# Google Cloud Pub/Sub helpers for Core Auto. Publish from step scripts; Pull for ingress bridges.

_PUBSUBCLIENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=lib/result.sh
source "${_PUBSUBCLIENT_DIR}/lib/result.sh"

_encode_value() {
  local value=$1
  if echo "$value" | jq -e . >/dev/null 2>&1; then echo "$value" | jq -c .; else printf '%s' "$value"; fi
}

Init() {
  if [[ -z "$(_pubsub_project)" ]]; then
    _pubsub_missing_env "PUBSUB_PROJECT_ID or GOOGLE_CLOUD_PROJECT"
    return 0
  fi
  _pubsub_set_result 200
}

Publish() {
  local value=$1 topic=${2:-${PUBSUB_TOPIC_ID:-}}
  local project payload err mid
  project=$(_pubsub_project)
  [[ -z $project ]] && { _pubsub_missing_env "PUBSUB_PROJECT_ID or GOOGLE_CLOUD_PROJECT"; return 0; }
  [[ -z $topic ]] && { _pubsub_missing_env "PUBSUB_TOPIC_ID"; return 0; }
  payload=$(_encode_value "$value")
  if command -v gcloud >/dev/null 2>&1; then
    if ! err=$(gcloud pubsub topics publish "$topic" --project="$project" --message="$payload" 2>&1); then
      _pubsub_transport_error "$err"
      return 0
    fi
    mid=$(echo "$err" | grep -oE 'messageIds:\[[^]]+\]' | head -1 || true)
    _pubsub_set_result 200 "" "$(jq -nc --arg m "$mid" '{message_id: $m}')"
    return 0
  fi
  if ! err=$(python3 - "$project" "$topic" <<'PY' 2>&1
import json, sys
try:
    from google.cloud import pubsub_v1
except ImportError:
    print("google-cloud-pubsub package or gcloud CLI required", file=sys.stderr); sys.exit(500)
project, topic_id = sys.argv[1], sys.argv[2]
payload = sys.stdin.read().encode()
publisher = pubsub_v1.PublisherClient()
topic_path = publisher.topic_path(project, topic_id)
message_id = publisher.publish(topic_path, payload).result(timeout=30)
print(json.dumps({"message_id": message_id}))
PY
<<< "$payload"); then
    if [[ "$err" == *google-cloud-pubsub* ]]; then _pubsub_set_result 500 "$err"; else _pubsub_transport_error "$err"; fi
    return 0
  fi
  _pubsub_set_result 200 "" "$err"
}

Pull() {
  local subscription=${1:-${PUBSUB_SUBSCRIPTION_ID:-}} max_messages=${2:-1} timeout_sec=${3:-30} ack=${4:-true}
  local project out
  project=$(_pubsub_project)
  [[ -z $project ]] && { _pubsub_missing_env "PUBSUB_PROJECT_ID or GOOGLE_CLOUD_PROJECT"; return 0; }
  [[ -z $subscription ]] && { _pubsub_missing_env "PUBSUB_SUBSCRIPTION_ID"; return 0; }
  if command -v gcloud >/dev/null 2>&1; then
    if ! out=$(gcloud pubsub subscriptions pull "$subscription" --project="$project" --limit="$max_messages" --auto-ack --format=json 2>&1); then
      _pubsub_transport_error "$out"
      return 0
    fi
    local messages
    messages=$(echo "$out" | jq -c --arg s "$subscription" '[.[] | {subscription: $s, message_id: .message.messageId, value: (.message.data | @base64d | try fromjson catch .)}] | {messages: .}')
    _pubsub_set_result 200 "" "$messages"
    QUEUE_RESULT=$PUBSUB_RESULT
    return 0
  fi
  if ! out=$(python3 - "$project" "$subscription" "$max_messages" "$timeout_sec" "$ack" <<'PY' 2>&1
import json, sys
try:
    from google.cloud import pubsub_v1
except ImportError:
    print("google-cloud-pubsub package required for Pull", file=sys.stderr); sys.exit(500)
project, sub_id = sys.argv[1], sys.argv[2]
max_messages, timeout_sec, ack = int(sys.argv[3]), float(sys.argv[4]), sys.argv[5].lower() == "true"
subscriber = pubsub_v1.SubscriberClient()
sub_path = subscriber.subscription_path(project, sub_id)
response = subscriber.pull(request={"subscription": sub_path, "max_messages": max(1, min(max_messages, 1000))}, timeout=timeout_sec)
messages = []
ack_ids = []
for received in response.received_messages:
    messages.append({"subscription": sub_id, "message_id": received.message.message_id, "value": received.message.data.decode()})
    ack_ids.append(received.ack_id)
if ack and ack_ids:
    subscriber.acknowledge(request={"subscription": sub_path, "ack_ids": ack_ids})
print(json.dumps({"messages": messages}))
PY
); then
    if [[ "$out" == *google-cloud-pubsub* ]]; then _pubsub_set_result 500 "$out"; else _pubsub_transport_error "$out"; fi
    return 0
  fi
  _pubsub_set_result 200 "" "$out"
  QUEUE_RESULT=$PUBSUB_RESULT
}
