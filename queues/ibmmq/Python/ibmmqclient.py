"""
Copyright Core DF

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

IBM MQ helpers for Core Auto. **Put** from step scripts; **Get** for
[ingress](../../ingress/Python/README.md) bridges only (not steps).
"""

import json
import os
from typing import Any, Optional

from lib.result import missing_env, transport_error


def _queue_name(explicit: Optional[str]) -> str:
    return explicit or os.environ.get("MQ_QUEUE", "")


def _encode(value: Any) -> bytes:
    if isinstance(value, bytes):
        return value
    if isinstance(value, (dict, list)):
        return json.dumps(value).encode("utf-8")
    return str(value).encode("utf-8")


def _decode(raw: bytes) -> Any:
    if isinstance(raw, str):
        raw = raw.encode("utf-8")
    try:
        return json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        return raw.decode("utf-8", errors="replace")


def _connect():
    import pymqi

    host = os.environ.get("MQ_HOST", "")
    port = os.environ.get("MQ_PORT", "1414")
    qmgr_name = os.environ.get("MQ_QUEUE_MANAGER", "")
    channel = os.environ.get("MQ_CHANNEL", "SYSTEM.DEF.SVRCONN")
    user = os.environ.get("MQ_USER", "")
    password = os.environ.get("MQ_PASSWORD", "")

    if not host or not qmgr_name:
        raise ValueError("MQ_HOST and MQ_QUEUE_MANAGER required")

    conn_info = f"{host}({port})"
    cd = pymqi.CD()
    cd.ChannelName = channel.encode()
    cd.ConnectionName = conn_info.encode()
    cd.ChannelType = pymqi.CMQC.MQCHT_CLNT
    cd.TransportType = pymqi.CMQC.MQXPT_TCP

    if user:
        return pymqi.connect(qmgr_name, cd, user, password)
    return pymqi.connect(qmgr_name, cd)


def Init() -> dict:
    if not os.environ.get("MQ_HOST") or not os.environ.get("MQ_QUEUE_MANAGER"):
        return missing_env("MQ_HOST and MQ_QUEUE_MANAGER")
    if not os.environ.get("MQ_QUEUE"):
        return missing_env("MQ_QUEUE (or pass queue per call)")
    return {"status_code": 200}


def Put(value: Any, queue: Optional[str] = None) -> dict:
    qname = _queue_name(queue)
    if not qname:
        return missing_env("MQ_QUEUE")
    try:
        import pymqi

        qmgr = _connect()
        q = pymqi.Queue(qmgr, qname)
        try:
            q.put(_encode(value))
        finally:
            q.close()
            qmgr.disconnect()
        return {"status_code": 200}
    except ImportError:
        return {"status_code": 500, "error": "pymqi package required (IBM MQ client libraries must be installed)"}
    except Exception as exc:
        return transport_error(str(exc))


def Get(
    queue: Optional[str] = None,
    timeout_sec: float = 30,
    max_messages: int = 1,
) -> dict:
    """Get messages from a queue (wait). For ingress processes only — not step scripts."""
    qname = _queue_name(queue)
    if not qname:
        return missing_env("MQ_QUEUE")
    try:
        import pymqi

        qmgr = _connect()
        q = pymqi.Queue(qmgr, qname)
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
                messages.append({"queue": qname, "value": _decode(msg)})
        finally:
            q.close()
            qmgr.disconnect()
        return {"status_code": 200, "messages": messages}
    except ImportError:
        return {"status_code": 500, "error": "pymqi package required (IBM MQ client libraries must be installed)"}
    except Exception as exc:
        return transport_error(str(exc))
