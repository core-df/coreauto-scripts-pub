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

Google Cloud Pub/Sub helpers for Core Auto. **Publish** from step scripts; **Pull** for
[ingress](../../ingress/Python/README.md) bridges only (not steps).
"""

import json
import os
from typing import Any, Optional

from lib.result import missing_env, transport_error


def _project_id() -> str:
    return os.environ.get("PUBSUB_PROJECT_ID", os.environ.get("GOOGLE_CLOUD_PROJECT", ""))


def _topic_id(explicit: Optional[str]) -> str:
    return explicit or os.environ.get("PUBSUB_TOPIC_ID", "")


def _subscription_id(explicit: Optional[str]) -> str:
    return explicit or os.environ.get("PUBSUB_SUBSCRIPTION_ID", "")


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
    if not _project_id():
        return missing_env("PUBSUB_PROJECT_ID or GOOGLE_CLOUD_PROJECT")
    return {"status_code": 200}


def Publish(value: Any, topic: Optional[str] = None) -> dict:
    project = _project_id()
    topic_id = _topic_id(topic)
    if not project:
        return missing_env("PUBSUB_PROJECT_ID or GOOGLE_CLOUD_PROJECT")
    if not topic_id:
        return missing_env("PUBSUB_TOPIC_ID")
    try:
        from google.cloud import pubsub_v1

        publisher = pubsub_v1.PublisherClient()
        topic_path = publisher.topic_path(project, topic_id)
        future = publisher.publish(topic_path, _encode(value))
        message_id = future.result(timeout=30)
        return {"status_code": 200, "message_id": message_id}
    except ImportError:
        return {"status_code": 500, "error": "google-cloud-pubsub package required"}
    except Exception as exc:
        return transport_error(str(exc))


def Pull(
    subscription: Optional[str] = None,
    max_messages: int = 1,
    timeout_sec: float = 30,
    ack: bool = True,
) -> dict:
    """Pull messages from a subscription. For ingress processes only — not step scripts."""
    project = _project_id()
    sub_id = _subscription_id(subscription)
    if not project:
        return missing_env("PUBSUB_PROJECT_ID or GOOGLE_CLOUD_PROJECT")
    if not sub_id:
        return missing_env("PUBSUB_SUBSCRIPTION_ID")
    try:
        from google.cloud import pubsub_v1

        subscriber = pubsub_v1.SubscriberClient()
        sub_path = subscriber.subscription_path(project, sub_id)
        response = subscriber.pull(
            request={
                "subscription": sub_path,
                "max_messages": max(1, min(max_messages, 1000)),
            },
            timeout=timeout_sec,
        )
        messages = []
        ack_ids = []
        for received in response.received_messages:
            messages.append(
                {
                    "subscription": sub_id,
                    "message_id": received.message.message_id,
                    "value": _decode(received.message.data),
                }
            )
            ack_ids.append(received.ack_id)
        if ack and ack_ids:
            subscriber.acknowledge(
                request={"subscription": sub_path, "ack_ids": ack_ids}
            )
        return {"status_code": 200, "messages": messages}
    except ImportError:
        return {"status_code": 500, "error": "google-cloud-pubsub package required"}
    except Exception as exc:
        return transport_error(str(exc))
