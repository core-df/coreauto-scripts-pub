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
# IBM MQ helpers for Core Auto. Put from step scripts; Get for ingress bridges.

_IBMMQCLIENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=lib/result.sh
source "${_IBMMQCLIENT_DIR}/lib/result.sh"

_encode_value() {
  local value=$1
  if echo "$value" | jq -e . >/dev/null 2>&1; then echo "$value" | jq -c .; else printf '%s' "$value"; fi
}

Init() {
  if [[ -z ${MQ_HOST:-} || -z ${MQ_QUEUE_MANAGER:-} ]]; then
    _ibmmq_missing_env "MQ_HOST and MQ_QUEUE_MANAGER"
    return 0
  fi
  if [[ -z ${MQ_QUEUE:-} ]]; then
    _ibmmq_missing_env "MQ_QUEUE (or pass queue per call)"
    return 0
  fi
  _ibmmq_set_result 200
}

Put() {
  local value=$1 queue=${2:-${MQ_QUEUE:-}}
  local payload err
  [[ -z $queue ]] && { _ibmmq_missing_env "MQ_QUEUE"; return 0; }
  payload=$(_encode_value "$value")
  if ! err=$(python3 - "$queue" <<'PY' 2>&1
import json, os, sys
try:
    import pymqi
except ImportError:
    print("pymqi package required (IBM MQ client libraries must be installed)", file=sys.stderr)
    sys.exit(500)
queue = sys.argv[1]
payload = sys.stdin.read().encode()
host = os.environ["MQ_HOST"]
port = os.environ.get("MQ_PORT", "1414")
qmgr = os.environ["MQ_QUEUE_MANAGER"]
channel = os.environ.get("MQ_CHANNEL", "SYSTEM.DEF.SVRCONN")
user = os.environ.get("MQ_USER", "")
password = os.environ.get("MQ_PASSWORD", "")
cd = pymqi.CD()
cd.ChannelName = channel.encode()
cd.ConnectionName = f"{host}({port})".encode()
cd.ChannelType = pymqi.CMQC.MQCHT_CLNT
cd.TransportType = pymqi.CMQC.MQXPT_TCP
qmgr_conn = pymqi.connect(qmgr, cd, user, password) if user else pymqi.connect(qmgr, cd)
q = pymqi.Queue(qmgr_conn, queue)
try:
    q.put(payload)
finally:
    q.close()
    qmgr_conn.disconnect()
PY
<<< "$payload"); then
    if [[ "$err" == *pymqi* ]]; then _ibmmq_set_result 500 "$err"; else _ibmmq_transport_error "$err"; fi
    return 0
  fi
  _ibmmq_set_result 200
}

Get() {
  local queue=${1:-${MQ_QUEUE:-}} timeout_sec=${2:-30} max_messages=${3:-1}
  local out
  [[ -z $queue ]] && { _ibmmq_missing_env "MQ_QUEUE"; return 0; }
  if ! out=$(python3 - "$queue" "$timeout_sec" "$max_messages" <<'PY' 2>&1
import json, os, sys
try:
    import pymqi
except ImportError:
    print("pymqi package required (IBM MQ client libraries must be installed)", file=sys.stderr)
    sys.exit(500)
queue, timeout_sec, max_messages = sys.argv[1], float(sys.argv[2]), int(sys.argv[3])
host = os.environ["MQ_HOST"]
port = os.environ.get("MQ_PORT", "1414")
qmgr = os.environ["MQ_QUEUE_MANAGER"]
channel = os.environ.get("MQ_CHANNEL", "SYSTEM.DEF.SVRCONN")
user = os.environ.get("MQ_USER", "")
password = os.environ.get("MQ_PASSWORD", "")
cd = pymqi.CD()
cd.ChannelName = channel.encode()
cd.ConnectionName = f"{host}({port})".encode()
cd.ChannelType = pymqi.CMQC.MQCHT_CLNT
cd.TransportType = pymqi.CMQC.MQXPT_TCP
qmgr_conn = pymqi.connect(qmgr, cd, user, password) if user else pymqi.connect(qmgr, cd)
q = pymqi.Queue(qmgr_conn, queue)
gmo = pymqi.GMO()
gmo.Options = pymqi.CMQC.MQGMO_WAIT | pymqi.CMQC.MQGMO_NO_SYNCPOINT
gmo.WaitInterval = int(timeout_sec * 1000)
messages = []
try:
    for _ in range(max(1, max_messages)):
        try:
            msg = q.get(None, pymqi.MD(), gmo)
        except pymqi.MQMIError as err:
            if err.reason == pymqi.CMQC.MQRC_NO_MSG_AVAILABLE:
                break
            raise
        try:
            val = json.loads(msg.decode())
        except Exception:
            val = msg.decode(errors="replace")
        messages.append({"queue": queue, "value": val})
finally:
    q.close()
    qmgr_conn.disconnect()
print(json.dumps({"messages": messages}))
PY
); then
    if [[ "$out" == *pymqi* ]]; then _ibmmq_set_result 500 "$out"; else _ibmmq_transport_error "$out"; fi
    return 0
  fi
  _ibmmq_set_result 200 "" "$out"
  QUEUE_RESULT=$IBMMQ_RESULT
}
