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

Kafka helpers for Core Auto. **Produce** from step scripts; **Consume** for
[ingress](../../ingress/Python/README.md) bridges only (not steps).
"""

import json
import os
from typing import Any, Optional

from lib.result import missing_env, transport_error

_bootstrap = os.environ.get("KAFKA_BOOTSTRAP_SERVERS", "")


def _config(extra: Optional[dict] = None) -> dict:
    cfg = {"bootstrap.servers": _bootstrap}
    if os.environ.get("KAFKA_SECURITY_PROTOCOL"):
        cfg["security.protocol"] = os.environ["KAFKA_SECURITY_PROTOCOL"]
    if os.environ.get("KAFKA_SASL_MECHANISM"):
        cfg["sasl.mechanism"] = os.environ["KAFKA_SASL_MECHANISM"]
    if os.environ.get("KAFKA_SASL_USERNAME"):
        cfg["sasl.username"] = os.environ["KAFKA_SASL_USERNAME"]
    if os.environ.get("KAFKA_SASL_PASSWORD"):
        cfg["sasl.password"] = os.environ["KAFKA_SASL_PASSWORD"]
    if extra:
        cfg.update(extra)
    return cfg


def Init() -> dict:
    if not _bootstrap:
        return missing_env("KAFKA_BOOTSTRAP_SERVERS")
    return {"status_code": 200}


def Produce(topic: str, value: Any, key: Optional[str] = None) -> dict:
    if not _bootstrap:
        return missing_env("KAFKA_BOOTSTRAP_SERVERS")
    try:
        from confluent_kafka import Producer
    except ImportError:
        return {"status_code": 500, "error": "confluent-kafka package required"}

    if isinstance(value, (dict, list)):
        payload = json.dumps(value).encode("utf-8")
    elif isinstance(value, bytes):
        payload = value
    else:
        payload = str(value).encode("utf-8")

    err_holder = []

    def _acked(err, msg):
        if err:
            err_holder.append(str(err))

    try:
        producer = Producer(_config())
        producer.produce(
            topic,
            payload,
            key=key.encode("utf-8") if key else None,
            callback=_acked,
        )
        producer.flush(timeout=30)
    except Exception as exc:
        return transport_error(str(exc))

    if err_holder:
        return {"status_code": 500, "error": err_holder[0]}
    return {"status_code": 200}


def Consume(
    topic: str,
    timeout_sec: float = 30,
    max_messages: int = 1,
    group_id: Optional[str] = None,
) -> dict:
    """Poll messages from a topic. For ingress processes only — not step scripts."""
    if not _bootstrap:
        return missing_env("KAFKA_BOOTSTRAP_SERVERS")
    try:
        from confluent_kafka import Consumer
    except ImportError:
        return {"status_code": 500, "error": "confluent-kafka package required"}

    gid = group_id or os.environ.get("KAFKA_GROUP_ID") or "coreauto-step"
    cfg = _config(
        {
            "group.id": gid,
            "auto.offset.reset": os.environ.get("KAFKA_AUTO_OFFSET_RESET", "earliest"),
        }
    )
    messages = []
    try:
        consumer = Consumer(cfg)
        consumer.subscribe([topic])
        deadline = timeout_sec
        while len(messages) < max_messages and deadline > 0:
            msg = consumer.poll(min(1.0, deadline))
            deadline -= 1.0
            if msg is None:
                continue
            if msg.error():
                consumer.close()
                return {"status_code": 500, "error": str(msg.error())}
            raw = msg.value()
            try:
                body = json.loads(raw.decode("utf-8"))
            except (UnicodeDecodeError, json.JSONDecodeError):
                body = raw.decode("utf-8", errors="replace")
            messages.append(
                {
                    "topic": msg.topic(),
                    "partition": msg.partition(),
                    "offset": msg.offset(),
                    "key": msg.key().decode("utf-8") if msg.key() else None,
                    "value": body,
                }
            )
        consumer.close()
    except Exception as exc:
        return transport_error(str(exc))

    return {"status_code": 200, "messages": messages}
