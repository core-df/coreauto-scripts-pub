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

Notification helpers: Slack, Microsoft Teams, email, PagerDuty.
"""

import os
import smtplib
from email.mime.text import MIMEText
from typing import Optional

import requests

from lib.result import missing_env, transport_error


def Slack(text: str, webhook_url: Optional[str] = None) -> dict:
    url = webhook_url or os.environ.get("SLACK_WEBHOOK_URL", "")
    if not url:
        return missing_env("SLACK_WEBHOOK_URL")
    try:
        resp = requests.post(url, json={"text": text}, timeout=30)
        if resp.status_code >= 400:
            return {"status_code": resp.status_code, "error": resp.text}
        return {"status_code": 200}
    except requests.RequestException as exc:
        return transport_error(str(exc))


def Teams(text: str, webhook_url: Optional[str] = None) -> dict:
    url = webhook_url or os.environ.get("TEAMS_WEBHOOK_URL", "")
    if not url:
        return missing_env("TEAMS_WEBHOOK_URL")
    payload = {"@type": "MessageCard", "@context": "http://schema.org/extensions", "text": text}
    try:
        resp = requests.post(url, json=payload, timeout=30)
        if resp.status_code >= 400:
            return {"status_code": resp.status_code, "error": resp.text}
        return {"status_code": 200}
    except requests.RequestException as exc:
        return transport_error(str(exc))


def Email(
    subject: str,
    body: str,
    to_addrs: str,
    from_addr: Optional[str] = None,
) -> dict:
    host = os.environ.get("SMTP_HOST", "")
    port = int(os.environ.get("SMTP_PORT", "587"))
    user = os.environ.get("SMTP_USER", "")
    password = os.environ.get("SMTP_PASSWORD", "")
    sender = from_addr or os.environ.get("SMTP_FROM", user)
    if not host or not sender:
        return missing_env("SMTP_HOST and SMTP_FROM (or from_addr)")

    msg = MIMEText(body)
    msg["Subject"] = subject
    msg["From"] = sender
    msg["To"] = to_addrs

    try:
        with smtplib.SMTP(host, port, timeout=60) as smtp:
            if user and password:
                smtp.starttls()
                smtp.login(user, password)
            smtp.sendmail(sender, [a.strip() for a in to_addrs.split(",")], msg.as_string())
        return {"status_code": 200}
    except smtplib.SMTPException as exc:
        return transport_error(str(exc))


def PagerDuty(summary: str, routing_key: Optional[str] = None, severity: str = "error") -> dict:
    key = routing_key or os.environ.get("PAGERDUTY_ROUTING_KEY", "")
    if not key:
        return missing_env("PAGERDUTY_ROUTING_KEY")
    payload = {
        "routing_key": key,
        "event_action": "trigger",
        "payload": {"summary": summary, "severity": severity, "source": "coreauto-step"},
    }
    try:
        resp = requests.post(
            "https://events.pagerduty.com/v2/enqueue",
            json=payload,
            timeout=30,
        )
        if resp.status_code >= 400:
            return {"status_code": resp.status_code, "error": resp.text}
        return {"status_code": 200, "body": resp.json()}
    except requests.RequestException as exc:
        return transport_error(str(exc))
