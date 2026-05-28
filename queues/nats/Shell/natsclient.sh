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
# NATS helpers for Core Auto. Publish from step scripts; Subscribe for ingress bridges.

_NATSCLIENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=lib/result.sh
source "${_NATSCLIENT_DIR}/lib/result.sh"

_encode_value() {
  local value=$1
  if echo "$value" | jq -e . >/dev/null 2>&1; then echo "$value" | jq -c .; else printf '%s' "$value"; fi
}

Init() {
  if [[ -z "$(_nats_servers)" ]]; then
    _nats_missing_env "NATS_URL or NATS_SERVERS"
    return 0
  fi
  _nats_set_result 200
}

Publish() {
  local subject=$1 value=$2 payload servers err
  servers=$(_nats_servers)
  [[ -z $servers ]] && { _nats_missing_env "NATS_URL or NATS_SERVERS"; return 0; }
  payload=$(_encode_value "$value")
  if command -v nats >/dev/null 2>&1; then
    if ! err=$(nats pub "$subject" "$payload" --server "$servers" 2>&1); then
      _nats_transport_error "$err"
      return 0
    fi
  elif ! err=$(python3 - "$subject" "$servers" <<PY 2>&1
import asyncio, json, sys
try:
    import nats
except ImportError:
    print("nats-py package or nats CLI required", file=sys.stderr); sys.exit(1)
subject, servers = sys.argv[1], sys.argv[2]
payload = sys.stdin.read().encode()
async def run():
    nc = await nats.connect(servers)
    await nc.publish(subject, payload)
    await nc.flush()
    await nc.drain()
asyncio.run(run())
PY
<<< "$payload"); then
    _nats_transport_error "$err"
    return 0
  fi
  _nats_set_result 200
}

Subscribe() {
  local subject=$1 timeout_sec=${2:-30} max_messages=${3:-1}
  local servers out tmp
  servers=$(_nats_servers)
  [[ -z $servers ]] && { _nats_missing_env "NATS_URL or NATS_SERVERS"; return 0; }
  if command -v nats >/dev/null 2>&1; then
    tmp=$(mktemp)
    timeout "$timeout_sec" nats sub "$subject" --server "$servers" --count "$max_messages" > "$tmp" 2>/dev/null || true
    out=$(grep -v '^#' "$tmp" | head -n "$max_messages" | jq -R . | jq -s -c --arg s "$subject" '[.[] | {subject: $s, value: (try fromjson catch .)}] | {messages: .}')
    rm -f "$tmp"
    _nats_set_result 200 "" "$out"
    QUEUE_RESULT=$NATS_RESULT
    return 0
  fi
  if ! out=$(python3 - "$subject" "$servers" "$timeout_sec" "$max_messages" <<'PY' 2>&1
import asyncio, json, sys
try:
    import nats
except ImportError:
    print("nats-py package required for Subscribe", file=sys.stderr); sys.exit(1)
subject, servers = sys.argv[1], sys.argv[2]
timeout_sec, max_messages = float(sys.argv[3]), int(sys.argv[4])
async def run():
    messages = []
    nc = await nats.connect(servers)
    sub = await nc.subscribe(subject)
    deadline = timeout_sec
    while len(messages) < max_messages and deadline > 0:
        wait = min(1.0, deadline)
        try:
            msg = await sub.next_msg(timeout=wait)
            try:
                val = json.loads(msg.data.decode())
            except Exception:
                val = msg.data.decode(errors="replace")
            messages.append({"subject": msg.subject, "value": val})
        except Exception:
            deadline -= wait
            continue
        deadline -= wait
    await nc.drain()
    print(json.dumps({"messages": messages}))
asyncio.run(run())
PY
); then
    _nats_transport_error "$out"
    return 0
  fi
  _nats_set_result 200 "" "$out"
  QUEUE_RESULT=$NATS_RESULT
}
