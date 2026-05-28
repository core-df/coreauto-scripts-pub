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

Azure Service Bus helpers for Core Auto. **Send** from step scripts; **Receive** for
[ingress](../../ingress/Python/README.md) bridges only (not steps).
"""

import json
import os
from typing import Any, Optional

from lib.result import missing_env, transport_error


def _connection_string() -> str:
    return os.environ.get("SERVICE_BUS_CONNECTION_STRING", "")


def _queue_name(explicit: Optional[str]) -> str:
    return explicit or os.environ.get("SERVICE_BUS_QUEUE_NAME", "")


def _encode(value: Any) -> bytes:
    if isinstance(value, bytes):
        return value
    if isinstance(value, (dict, list)):
        return json.dumps(value).encode("utf-8")
    return str(value).encode("utf-8")


def _decode(raw: bytes) -> Any:
    try:
        return json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        return raw.decode("utf-8", errors="replace")


def Init() -> dict:
    if not _connection_string():
        return missing_env("SERVICE_BUS_CONNECTION_STRING")
    if not os.environ.get("SERVICE_BUS_QUEUE_NAME"):
        return missing_env("SERVICE_BUS_QUEUE_NAME (or pass queue per call)")
    return {"status_code": 200}


def Send(value: Any, queue: Optional[str] = None) -> dict:
    conn = _connection_string()
    q = _queue_name(queue)
    if not conn:
        return missing_env("SERVICE_BUS_CONNECTION_STRING")
    if not q:
        return missing_env("SERVICE_BUS_QUEUE_NAME")
    try:
        from azure.servicebus import ServiceBusClient, ServiceBusMessage

        with ServiceBusClient.from_connection_string(conn) as client:
            sender = client.get_queue_sender(queue_name=q)
            with sender:
                sender.send_messages(ServiceBusMessage(body=_encode(value)))
        return {"status_code": 200}
    except Exception as exc:
        return transport_error(str(exc))


def Receive(
    queue: Optional[str] = None,
    timeout_sec: float = 30,
    max_messages: int = 1,
    complete: bool = True,
) -> dict:
    """Receive messages from a queue. For ingress processes only — not step scripts."""
    conn = _connection_string()
    q = _queue_name(queue)
    if not conn:
        return missing_env("SERVICE_BUS_CONNECTION_STRING")
    if not q:
        return missing_env("SERVICE_BUS_QUEUE_NAME")
    try:
        from azure.servicebus import ServiceBusClient

        messages = []
        with ServiceBusClient.from_connection_string(conn) as client:
            receiver = client.get_queue_receiver(queue_name=q)
            with receiver:
                batch = receiver.receive_messages(
                    max_message_count=max(1, max_messages),
                    max_wait_time=int(timeout_sec),
                )
                for msg in batch:
                    raw = msg.body
                    if not isinstance(raw, bytes):
                        raw = b"".join(raw)
                    messages.append(
                        {
                            "queue": q,
                            "message_id": str(msg.message_id) if msg.message_id else None,
                            "value": _decode(raw),
                        }
                    )
                    if complete:
                        receiver.complete_message(msg)
        return {"status_code": 200, "messages": messages}
    except Exception as exc:
        return transport_error(str(exc))
