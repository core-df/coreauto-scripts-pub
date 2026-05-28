#!/usr/bin/env python3
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

Core Auto real-time step — demonstrates combining snippet libraries.

Scenario: order-enrichment step
  1. cawbs — read event, keystore, write step output
  2. transform — parse CSV / XML / JSON payloads
  3. files — read local drop file, write ack, optional SFTP upload
  4. http — validate order with partner API
  5. s3 — load config, store enriched result
  6. queues — fan-out enriched order to every configured backend
  7. notify — Slack / Teams / email / PagerDuty on outcome

Set only the env vars you need; optional integrations are skipped.
"""

import json
import os
import sys
from typing import Any, Callable, Dict, List, Optional

import lib_paths

lib_paths.setup()

import cawbs
import fileclient as files
import httpclient as http
import ibmmqclient as ibmmq
import kafkaclient as kafka
import natsclient as nats
import notifyclient as notify
import pubsubclient as pubsub
import rabbitclient as rabbit
import redisclient as redis
import s3client as s3
import servicebusclient as servicebus
import sqsclient as sqs
import transformclient as transform


def _fail(result: dict, label: str) -> None:
    print(json.dumps({"step": label, "error": result}, indent=2), file=sys.stderr)
    sys.exit(1)


def _ok(result: dict, label: str) -> dict:
    code = result.get("status_code", 0)
    if code >= 400 or code == 0:
        _fail(result, label)
    return result


def _optional(label: str, fn: Callable[[], dict]) -> Optional[dict]:
    result = fn()
    code = result.get("status_code", 0)
    if code in (601, 500) and "missing" in str(result.get("error", "")).lower():
        print(f"[skip] {label}: not configured")
        return None
    if code >= 400 or code == 0:
        print(f"[warn] {label}: {result.get('error', result)}")
        return None
    print(f"[ok] {label}")
    return result


def _load_input(event: dict) -> dict:
    """Build working order from event payload + optional local files."""
    order = dict(event.get("payload") or event)
    order_id = order.get("orderId") or order.get("id") or "unknown"

    csv_path = order.get("csvPath") or os.environ.get("EXAMPLE_CSV_PATH", "")
    if csv_path:
        raw = _ok(files.LocalRead(csv_path), "files.LocalRead")
        rows = _ok(transform.CsvToRows(raw["content"]), "transform.CsvToRows")
        if rows["rows"]:
            order["lineItems"] = rows["rows"]

    xml_path = order.get("xmlPath") or os.environ.get("EXAMPLE_XML_PATH", "")
    if xml_path:
        raw = _ok(files.LocalRead(xml_path), "files.LocalRead(xml)")
        parsed = _ok(transform.XmlToDict(raw["content"]), "transform.XmlToDict")
        order["xml"] = parsed["data"]

    return {"orderId": order_id, "details": order}


def _partner_check(order_id: str, api_key: str) -> dict:
    base = os.environ.get("PARTNER_API_URL", "").rstrip("/")
    if not base:
        return {"status_code": 200, "skipped": True}
    url = f"{base}/orders/{order_id}"
    headers = {"Authorization": f"Bearer {api_key}"} if api_key else {}
    return _ok(http.Get(url, headers=headers), "http.Get(partner)")


def _s3_enrich(order: dict) -> dict:
    prefix = os.environ.get("S3_CONFIG_PREFIX", "config/")
    got = _optional("s3.GetObject", lambda: s3.GetObject(f"{prefix}enrichment.json"))
    if got and got.get("content"):
        cfg = _ok(transform.JsonParse(got["content"]), "transform.JsonParse(config)")
        order["config"] = cfg["data"]

    out_key = f"orders/{order['orderId']}/enriched.json"
    body = _ok(transform.JsonStringify(order), "transform.JsonStringify")
    _optional("s3.PutObject", lambda: s3.PutObject(out_key, body["text"]))
    _optional("s3.ListObjects", lambda: s3.ListObjects(prefix="orders/"))
    return order


def _publish_all_queues(order: dict) -> List[str]:
    """Fan-out to every queue backend that is configured."""
    payload = order
    published: List[str] = []
    topic = os.environ.get("EXAMPLE_KAFKA_TOPIC", "orders.enriched")
    queue = os.environ.get("EXAMPLE_QUEUE_NAME", "orders")
    subject = os.environ.get("EXAMPLE_NATS_SUBJECT", "orders.enriched")

    backends = (
        ("kafka", lambda: kafka.Produce(topic, payload)),
        ("rabbit", lambda: rabbit.Publish(queue, payload)),
        ("sqs", lambda: sqs.Send(payload)),
        ("redis", lambda: redis.Push(queue, payload)),
        ("servicebus", lambda: servicebus.Send(payload)),
        ("nats", lambda: nats.Publish(subject, payload)),
        ("ibmmq", lambda: ibmmq.Put(payload, queue=queue)),
        ("pubsub", lambda: pubsub.Publish(payload)),
    )
    for name, fn in backends:
        if _optional(f"queues.{name}", fn):
            published.append(name)
    return published


def _notify_all(summary: str, success: bool) -> List[str]:
    sent: List[str] = []
    if os.environ.get("SLACK_WEBHOOK_URL"):
        if _optional("notify.Slack", lambda: notify.Slack(summary)):
            sent.append("slack")
    if os.environ.get("TEAMS_WEBHOOK_URL"):
        if _optional("notify.Teams", lambda: notify.Teams(summary)):
            sent.append("teams")
    if os.environ.get("SMTP_HOST"):
        to_addr = os.environ.get("EXAMPLE_ALERT_EMAIL", "ops@example.com")
        if _optional(
            "notify.Email",
            lambda: notify.Email(
                "Core Auto order step",
                summary,
                to_addr,
            ),
        ):
            sent.append("email")
    if not success and os.environ.get("PAGERDUTY_ROUTING_KEY"):
        if _optional("notify.PagerDuty", lambda: notify.PagerDuty(summary)):
            sent.append("pagerduty")
    return sent


def main() -> None:
    _ok(cawbs.Init(), "cawbs.Init")

    event = _ok(cawbs.GetEventPayload(), "cawbs.GetEventPayload")
    order = _load_input(event)

    secrets = _optional(
        "cawbs.GetKeystore",
        lambda: cawbs.GetKeystore(os.environ.get("EXAMPLE_KEYSTORE_KEYS", "partner_api_key")),
    )
    api_key = ""
    if secrets and secrets.get("answer"):
        api_key = secrets["answer"].get("partner_api_key", "")

    partner = _partner_check(order["orderId"], api_key)
    if not partner.get("skipped"):
        order["partner"] = partner.get("body")

    if os.environ.get("PARTNER_WEBHOOK_URL"):
        post_body = {"orderId": order["orderId"], "status": "enriched"}
        _optional(
            "http.Post(webhook)",
            lambda: http.Post(os.environ["PARTNER_WEBHOOK_URL"], json_body=post_body),
        )

    order = _s3_enrich(order)

    ack_dir = os.environ.get("EXAMPLE_ACK_DIR", "/tmp/coreauto-example")
    ack_path = f"{ack_dir}/{order['orderId']}.json"
    ack_text = _ok(transform.JsonStringify(order), "transform.JsonStringify(ack)")
    _ok(files.LocalWrite(ack_path, ack_text["text"]), "files.LocalWrite")

    inbox = order.get("details", {}).get("csvPath") or os.environ.get("EXAMPLE_CSV_PATH", "")
    if inbox and os.path.isfile(inbox):
        done_path = f"{ack_dir}/{order['orderId']}.done"
        _optional("files.LocalMove", lambda: files.LocalMove(inbox, done_path))

    if os.environ.get("SFTP_HOST"):
        remote = os.environ.get("EXAMPLE_SFTP_REMOTE", f"/outgoing/{order['orderId']}.json")
        _optional("files.SftpPut", lambda: files.SftpPut(ack_path, remote))

    published = _publish_all_queues(order)

    summary = (
        f"Order {order['orderId']} enriched; "
        f"queues={','.join(published) or 'none'}; step={os.environ.get('STEPNAME', '?')}"
    )
    notified = _notify_all(summary, success=True)

    output = {
        "orderId": order["orderId"],
        "queuesPublished": published,
        "notificationsSent": notified,
        "ackPath": ack_path,
    }
    _ok(cawbs.PutStepPayload(output), "cawbs.PutStepPayload")

    status = _optional("cawbs.GetEventStatus", lambda: cawbs.GetEventStatus())
    if status:
        output["runStatus"] = status.get("status")

    print(json.dumps({"status_code": 200, "result": output}, indent=2))


if __name__ == "__main__":
    main()
