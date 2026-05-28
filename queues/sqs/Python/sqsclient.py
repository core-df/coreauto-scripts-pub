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

Amazon SQS helpers for Core Auto. **Send** from step scripts; **Receive** for
[ingress](../../ingress/Python/README.md) bridges only (not steps).
"""

import json
import os
from typing import Any, Optional

from lib.result import missing_env, transport_error


def _client():
    import boto3

    region = os.environ.get("AWS_REGION", os.environ.get("AWS_DEFAULT_REGION", "us-east-1"))
    endpoint = os.environ.get("SQS_ENDPOINT_URL", None)
    kwargs = {"region_name": region}
    if endpoint:
        kwargs["endpoint_url"] = endpoint
    return boto3.client("sqs", **kwargs)


def _queue_url(explicit: Optional[str]) -> str:
    return explicit or os.environ.get("SQS_QUEUE_URL", "")


def _encode(value: Any) -> str:
    if isinstance(value, str):
        return value
    if isinstance(value, (dict, list)):
        return json.dumps(value)
    return str(value)


def _decode(raw: str) -> Any:
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return raw


def Init() -> dict:
    if not os.environ.get("AWS_ACCESS_KEY_ID") and not os.environ.get("AWS_PROFILE"):
        return missing_env("AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY or AWS_PROFILE")
    if not os.environ.get("SQS_QUEUE_URL"):
        return missing_env("SQS_QUEUE_URL (or pass queue_url per call)")
    return {"status_code": 200}


def Send(value: Any, queue_url: Optional[str] = None) -> dict:
    url = _queue_url(queue_url)
    if not url:
        return missing_env("SQS_QUEUE_URL")
    try:
        client = _client()
        resp = client.send_message(QueueUrl=url, MessageBody=_encode(value))
        return {"status_code": 200, "message_id": resp.get("MessageId")}
    except Exception as exc:
        return transport_error(str(exc))


def Receive(
    queue_url: Optional[str] = None,
    max_messages: int = 1,
    wait_time_sec: int = 10,
    delete: bool = True,
) -> dict:
    """Long-poll messages from a queue. For ingress processes only — not step scripts."""
    url = _queue_url(queue_url)
    if not url:
        return missing_env("SQS_QUEUE_URL")
    max_messages = max(1, min(max_messages, 10))
    try:
        client = _client()
        resp = client.receive_message(
            QueueUrl=url,
            MaxNumberOfMessages=max_messages,
            WaitTimeSeconds=wait_time_sec,
        )
        messages = []
        for item in resp.get("Messages", []):
            messages.append(
                {
                    "message_id": item.get("MessageId"),
                    "receipt_handle": item.get("ReceiptHandle"),
                    "value": _decode(item.get("Body", "")),
                }
            )
            if delete and item.get("ReceiptHandle"):
                client.delete_message(QueueUrl=url, ReceiptHandle=item["ReceiptHandle"])
        return {"status_code": 200, "messages": messages}
    except Exception as exc:
        return transport_error(str(exc))
