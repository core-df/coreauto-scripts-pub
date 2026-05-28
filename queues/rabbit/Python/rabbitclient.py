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

RabbitMQ helpers for Core Auto. **Publish** from step scripts; **Consume** for
[ingress](../../ingress/Python/README.md) bridges only (not steps).
"""

import json
import os
from typing import Any, Optional
from urllib.parse import quote

from lib.result import missing_env, transport_error


def _connection_url() -> str:
    url = os.environ.get("RABBITMQ_URL", "")
    if url:
        return url
    host = os.environ.get("RABBITMQ_HOST", "")
    if not host:
        return ""
    port = os.environ.get("RABBITMQ_PORT", "5672")
    user = quote(os.environ.get("RABBITMQ_USER", "guest"), safe="")
    password = quote(os.environ.get("RABBITMQ_PASSWORD", "guest"), safe="")
    vhost = quote(os.environ.get("RABBITMQ_VHOST", "/"), safe="")
    return f"amqp://{user}:{password}@{host}:{port}/{vhost}"


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
    if not _connection_url():
        return missing_env("RABBITMQ_URL or RABBITMQ_HOST")
    return {"status_code": 200}


def Publish(queue: str, value: Any, durable: bool = True) -> dict:
    url = _connection_url()
    if not url:
        return missing_env("RABBITMQ_URL or RABBITMQ_HOST")
    try:
        import pika

        connection = pika.BlockingConnection(pika.URLParameters(url))
        channel = connection.channel()
        channel.queue_declare(queue=queue, durable=durable)
        channel.basic_publish(exchange="", routing_key=queue, body=_encode(value))
        connection.close()
        return {"status_code": 200}
    except Exception as exc:
        return transport_error(str(exc))


def Consume(
    queue: str,
    timeout_sec: float = 30,
    max_messages: int = 1,
    auto_ack: bool = True,
    durable: bool = True,
) -> dict:
    """Poll messages from a queue. For ingress processes only — not step scripts."""
    url = _connection_url()
    if not url:
        return missing_env("RABBITMQ_URL or RABBITMQ_HOST")
    try:
        import pika

        connection = pika.BlockingConnection(pika.URLParameters(url))
        channel = connection.channel()
        channel.queue_declare(queue=queue, durable=durable)
        messages = []
        deadline = timeout_sec
        for method_frame, _properties, body in channel.consume(queue, inactivity_timeout=1):
            if method_frame is None:
                deadline -= 1.0
                if deadline <= 0:
                    break
                continue
            messages.append(
                {
                    "queue": queue,
                    "delivery_tag": method_frame.delivery_tag,
                    "value": _decode(body),
                }
            )
            if auto_ack:
                channel.basic_ack(method_frame.delivery_tag)
            if len(messages) >= max_messages:
                break
        channel.cancel()
        connection.close()
        return {"status_code": 200, "messages": messages}
    except Exception as exc:
        return transport_error(str(exc))
