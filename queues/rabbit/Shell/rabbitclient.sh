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
# RabbitMQ helpers for Core Auto. Publish from step scripts; Consume for ingress bridges.

_RABBITCLIENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=lib/result.sh
source "${_RABBITCLIENT_DIR}/lib/result.sh"

_encode_value() {
  local value=$1
  if echo "$value" | jq -e . >/dev/null 2>&1; then
    echo "$value" | jq -c .
  else
    printf '%s' "$value"
  fi
}

_rabbit_url() {
  if [[ -n ${RABBITMQ_URL:-} ]]; then
    echo "$RABBITMQ_URL"
    return 0
  fi
  [[ -z ${RABBITMQ_HOST:-} ]] && return 0
  python3 -c "import urllib.parse as u; print('amqp://%s:%s@%s:%s/%s' % (u.quote('${RABBITMQ_USER:-guest}'), u.quote('${RABBITMQ_PASSWORD:-guest}'), '${RABBITMQ_HOST}', '${RABBITMQ_PORT:-5672}', u.quote('${RABBITMQ_VHOST:-/}', safe='')))"
}

Init() {
  if [[ -z "$(_rabbit_url)" ]]; then
    _rabbit_missing_env "RABBITMQ_URL or RABBITMQ_HOST"
    return 0
  fi
  _rabbit_set_result 200
}

Publish() {
  local queue=$1 value=$2 durable=${3:-true}
  local url payload err
  url=$(_rabbit_url)
  if [[ -z $url ]]; then
    _rabbit_missing_env "RABBITMQ_URL or RABBITMQ_HOST"
    return 0
  fi
  payload=$(_encode_value "$value")
  if command -v rabbitmqadmin >/dev/null 2>&1; then
    if ! err=$(rabbitmqadmin publish routing_key="$queue" payload="$payload" 2>&1); then
      _rabbit_transport_error "$err"
      return 0
    fi
  elif ! err=$(python3 - "$url" "$queue" "$payload" <<'PY' 2>&1
import json, sys
try:
    import pika
except ImportError:
    print("pika package or rabbitmqadmin CLI required", file=sys.stderr)
    sys.exit(1)
url, queue, payload = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    body = json.dumps(json.loads(payload)).encode()
except json.JSONDecodeError:
    body = payload.encode()
conn = pika.BlockingConnection(pika.URLParameters(url))
ch = conn.channel()
ch.queue_declare(queue=queue, durable=True)
ch.basic_publish(exchange="", routing_key=queue, body=body)
conn.close()
PY
); then
    _rabbit_transport_error "$err"
    return 0
  fi
  _rabbit_set_result 200
}

Consume() {
  local queue=$1 timeout_sec=${2:-30} max_messages=${3:-1}
  local url out
  url=$(_rabbit_url)
  if [[ -z $url ]]; then
    _rabbit_missing_env "RABBITMQ_URL or RABBITMQ_HOST"
    return 0
  fi
  if ! out=$(python3 - "$url" "$queue" "$timeout_sec" "$max_messages" <<'PY' 2>&1
import json, sys
try:
    import pika
except ImportError:
    print("pika package required for Consume", file=sys.stderr)
    sys.exit(1)
url, queue, timeout_sec, max_messages = sys.argv[1], sys.argv[2], float(sys.argv[3]), int(sys.argv[4])
conn = pika.BlockingConnection(pika.URLParameters(url))
ch = conn.channel()
ch.queue_declare(queue=queue, durable=True)
messages = []
deadline = timeout_sec
for method, _props, body in ch.consume(queue, inactivity_timeout=1):
    if method is None:
        deadline -= 1
        if deadline <= 0:
            break
        continue
    try:
        val = json.loads(body.decode())
    except Exception:
        val = body.decode(errors="replace")
    messages.append({"queue": queue, "delivery_tag": method.delivery_tag, "value": val})
    ch.basic_ack(method.delivery_tag)
    if len(messages) >= max_messages:
        break
ch.cancel()
conn.close()
print(json.dumps({"messages": messages}))
PY
); then
    _rabbit_transport_error "$out"
    return 0
  fi
  _rabbit_set_result 200 "" "$out"
  QUEUE_RESULT=$RABBIT_RESULT
}
