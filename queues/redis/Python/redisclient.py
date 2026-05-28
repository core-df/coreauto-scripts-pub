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

Redis list helpers for Core Auto. **Push** from step scripts; **Pop** for
[ingress](../../ingress/Python/README.md) bridges only (not steps).
"""

import json
import os
from typing import Any

from lib.result import missing_env, transport_error


def _connection_url() -> str:
    url = os.environ.get("REDIS_URL", "")
    if url:
        return url
    host = os.environ.get("REDIS_HOST", "")
    if not host:
        return ""
    port = os.environ.get("REDIS_PORT", "6379")
    password = os.environ.get("REDIS_PASSWORD", "")
    db = os.environ.get("REDIS_DB", "0")
    if password:
        return f"redis://:{password}@{host}:{port}/{db}"
    return f"redis://{host}:{port}/{db}"


def _client():
    import redis

    return redis.from_url(_connection_url(), decode_responses=False)


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
        return missing_env("REDIS_URL or REDIS_HOST")
    return {"status_code": 200}


def Push(queue: str, value: Any) -> dict:
    if not _connection_url():
        return missing_env("REDIS_URL or REDIS_HOST")
    try:
        client = _client()
        client.lpush(queue, _encode(value))
        return {"status_code": 200}
    except Exception as exc:
        return transport_error(str(exc))


def Pop(queue: str, timeout_sec: float = 30, max_messages: int = 1) -> dict:
    """Blocking dequeue from a list. For ingress processes only — not step scripts."""
    if not _connection_url():
        return missing_env("REDIS_URL or REDIS_HOST")
    messages = []
    try:
        client = _client()
        remaining = max(1, max_messages)
        while remaining > 0:
            wait = max(1, int(timeout_sec)) if remaining == max_messages else 1
            item = client.brpop(queue, timeout=wait)
            if item is None:
                break
            _key, body = item
            messages.append({"queue": queue, "value": _decode(body)})
            remaining -= 1
            timeout_sec -= wait
            if timeout_sec <= 0:
                break
        return {"status_code": 200, "messages": messages}
    except Exception as exc:
        return transport_error(str(exc))
