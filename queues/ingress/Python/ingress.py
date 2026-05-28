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

Queue ingress bridge — consume from a queue and submit Core Auto events via cawbs.

Run as a long-lived process on a worker or sidecar, NOT inside a Core Auto step.
Each message consumed is forwarded with cawbsingress.PostEvent().
"""

import os
import sys
from typing import Any, Callable, Optional

from lib.result import missing_env


def _load_cawbsingress():
    cawbs_dir = os.environ.get(
        "CAWBS_PYTHON",
        os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", "cawbs", "Python")),
    )
    if cawbs_dir not in sys.path:
        sys.path.insert(0, cawbs_dir)
    import cawbsingress

    return cawbsingress


def TriggerEvent(
    payload: Any,
    event_name: Optional[str] = None,
    event_source: Optional[str] = None,
) -> dict:
    """Submit payload to the Collector as a real-time event (POST /v1/rtevent)."""
    name = event_name or os.environ.get("CA_EVENT_NAME", "")
    if not name:
        return missing_env("CA_EVENT_NAME (or pass event_name)")

    source = event_source if event_source is not None else os.environ.get("CA_EVENT_SOURCE", "")
    cawbs = _load_cawbsingress()
    init = cawbs.Init()
    if init.get("status_code", 0) >= 400:
        return init

    kwargs = {"event_name": name, "payload": payload}
    if source:
        kwargs["event_source"] = source
    return cawbs.PostEvent(**kwargs)


def ForwardMessages(consume_result: dict) -> dict:
    """Forward messages from a queue client consume result to Core Auto."""
    if consume_result.get("status_code") != 200:
        return consume_result

    forwarded = []
    for msg in consume_result.get("messages", []):
        value = msg.get("value", msg)
        result = TriggerEvent(value)
        if result.get("status_code", 0) >= 400:
            return result
        forwarded.append(
            {
                "actionId": result.get("actionId"),
                "eventId": result.get("eventId"),
            }
        )
    return {"status_code": 200, "forwarded": forwarded}


def RunBridge(consume_fn: Callable[..., dict], **consume_kwargs) -> dict:
    """Consume once from a queue backend and forward all messages as events."""
    return ForwardMessages(consume_fn(**consume_kwargs))
