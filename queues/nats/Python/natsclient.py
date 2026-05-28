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

NATS helpers for Core Auto. **Publish** from step scripts; **Subscribe** for
[ingress](../../ingress/Python/README.md) bridges only (not steps).
"""

import asyncio
import json
import os
from typing import Any

from lib.result import missing_env, transport_error


def _servers() -> str:
    return os.environ.get("NATS_URL", os.environ.get("NATS_SERVERS", ""))


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
    if not _servers():
        return missing_env("NATS_URL or NATS_SERVERS")
    return {"status_code": 200}


async def _publish(subject: str, value: Any) -> dict:
    import nats

    nc = await nats.connect(_servers())
    try:
        await nc.publish(subject, _encode(value))
        await nc.flush()
        return {"status_code": 200}
    except Exception as exc:
        return transport_error(str(exc))
    finally:
        await nc.drain()


def Publish(subject: str, value: Any) -> dict:
    if not _servers():
        return missing_env("NATS_URL or NATS_SERVERS")
    return asyncio.run(_publish(subject, value))


async def _subscribe(
    subject: str,
    timeout_sec: float,
    max_messages: int,
) -> dict:
    import nats

    messages = []
    try:
        nc = await nats.connect(_servers())
        sub = await nc.subscribe(subject)
        deadline = timeout_sec
        while len(messages) < max_messages and deadline > 0:
            wait = min(1.0, deadline)
            try:
                msg = await sub.next_msg(timeout=wait)
            except nats.errors.TimeoutError:
                deadline -= wait
                continue
            messages.append(
                {
                    "subject": msg.subject,
                    "value": _decode(msg.data),
                }
            )
            deadline -= wait
        await nc.drain()
        return {"status_code": 200, "messages": messages}
    except Exception as exc:
        return transport_error(str(exc))


def Subscribe(
    subject: str,
    timeout_sec: float = 30,
    max_messages: int = 1,
) -> dict:
    """Poll messages on a subject. For ingress processes only — not step scripts."""
    if not _servers():
        return missing_env("NATS_URL or NATS_SERVERS")
    return asyncio.run(_subscribe(subject, timeout_sec, max_messages))
