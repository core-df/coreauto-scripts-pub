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

Core Auto Web Services — ingress client for the Collector.

Use outside step scripts (queue bridges, schedulers, file watchers) to submit
events and flags that trigger Core Auto real-time or batch workflows.

Documentation: https://coreauto.coredf.com/resources
Collector API: POST /v1/rtevent, POST /v1/flag, GET /v1/rtevent/list, etc.

Required environment variables:
    ENV            - Target environment name (Environment header).
    CA_ACCESS_CODE - API access code used to obtain a bearer token.
    CA_WBS_URL     - Base URL of the Core Auto Collector web service.

Typical usage:
    import cawbsingress
    cawbsingress.Init()
    cawbsingress.PostEvent("OrderCreated", {"orderId": "123"})
"""

import json
import os
from typing import Any, Optional

import requests

wbs_iniflag = False
wbs_env = os.environ.get("ENV")
wbs_accesscode = os.environ.get("CA_ACCESS_CODE")
wbs_url = os.environ.get("CA_WBS_URL")
wbs_headers = {}


def Init():
    """Authenticate with the Collector (no ACTIONID / STEPNAME required)."""
    global wbs_headers, wbs_iniflag, wbs_url

    if wbs_env is None or wbs_accesscode is None or wbs_url is None:
        return {
            "status_code": 601,
            "error": "Environment variables ENV, CA_ACCESS_CODE, CA_WBS_URL should be defined",
        }
    if wbs_iniflag:
        return {"status_code": 602, "error": "init already called"}

    wbs_url = wbs_url.strip("/ ")
    todo = {"apiCode": wbs_accesscode}
    wbs_headers = {"Content-Type": "application/json", "Environment": wbs_env}
    response = requests.post(wbs_url + "/v1/auth/apicode", data=json.dumps(todo), headers=wbs_headers)

    if response.status_code >= 400:
        try:
            js = response.json()
        except Exception:
            return {"status_code": response.status_code, "error": "inaccessible"}
        return {"status_code": response.status_code, "error": js}

    js = response.json()
    wbs_headers["Authorization"] = "Bearer " + js["token"]
    wbs_iniflag = True
    return {"status_code": response.status_code}


def PostEvent(
    event_name: str,
    payload: Any,
    event_source: Optional[str] = None,
) -> dict:
    """Submit an event to the Collector (POST /v1/rtevent).

    Triggers a Core Auto real-time workflow. Returns actionId and eventId on success.
    """
    if not wbs_iniflag:
        return {"status_code": 603, "error": "Init required"}

    body = {"eventName": event_name, "payload": payload}
    if event_source is not None:
        body["eventSource"] = event_source

    response = requests.post(
        wbs_url + "/v1/rtevent",
        data=json.dumps(body),
        headers=wbs_headers,
    )

    if response.status_code >= 400:
        try:
            js = response.json()
        except Exception:
            return {"status_code": response.status_code, "error": "inaccessible"}
        return {"status_code": response.status_code, "error": js}

    js = response.json()
    return {
        "status_code": response.status_code,
        "eventId": js.get("eventId"),
        "actionId": js.get("actionId"),
        "createdAt": js.get("createdAt"),
    }


def GetEventStatus(action_id: int) -> dict:
    """Return execution status for an action (GET /v1/rtevent/status/{actionid})."""
    if not wbs_iniflag:
        return {"status_code": 603, "error": "Init required"}

    response = requests.get(
        wbs_url + "/v1/rtevent/status/" + str(action_id),
        headers=wbs_headers,
    )

    if response.status_code >= 400:
        try:
            js = response.json()
        except Exception:
            return {"status_code": response.status_code, "error": "inaccessible"}
        return {"status_code": response.status_code, "error": js}

    return {"status_code": response.status_code, "status": response.json()}


def GetEventList() -> dict:
    """List available event definitions (GET /v1/rtevent/list)."""
    if not wbs_iniflag:
        return {"status_code": 603, "error": "Init required"}

    response = requests.get(wbs_url + "/v1/rtevent/list", headers=wbs_headers)

    if response.status_code >= 400:
        try:
            js = response.json()
        except Exception:
            return {"status_code": response.status_code, "error": "inaccessible"}
        return {"status_code": response.status_code, "error": js}

    return {"status_code": response.status_code, "events": response.json()}


def SubmitFlag(
    name: str,
    system_name: str,
    source_system_name: str,
    date: str,
) -> dict:
    """Submit a batch flag (POST /v1/flag). Date format: YYYY-MM-DD."""
    if not wbs_iniflag:
        return {"status_code": 603, "error": "Init required"}

    body = {
        "name": name,
        "systemName": system_name,
        "sourceSystemName": source_system_name,
        "date": date,
    }
    response = requests.post(
        wbs_url + "/v1/flag",
        data=json.dumps(body),
        headers=wbs_headers,
    )

    if response.status_code >= 400:
        try:
            js = response.json()
        except Exception:
            return {"status_code": response.status_code, "error": "inaccessible"}
        return {"status_code": response.status_code, "error": js}

    js = response.json()
    return {"status_code": response.status_code, "flagStatus": js.get("status")}


def GetKeystore(keylist: str) -> dict:
    """Fetch secrets from the Collector keystore (GET /v1/keystore/{keys})."""
    if not wbs_iniflag:
        return {"status_code": 603, "error": "Init required"}

    keys = keylist.replace(" ", "")
    response = requests.get(wbs_url + "/v1/keystore/" + keys, headers=wbs_headers)

    if response.status_code >= 400:
        try:
            js = response.json()
        except Exception:
            return {"status_code": response.status_code, "error": "inaccessible"}
        return {"status_code": response.status_code, "error": js}

    js = response.json()
    for key in keys.split(","):
        if key not in js:
            return {"status_code": 605, "error": key + " not found"}
    return {"status_code": response.status_code, "answer": js}
