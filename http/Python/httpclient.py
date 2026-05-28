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

Generic HTTP client helpers for Core Auto step scripts (non-Collector REST calls).
"""

from typing import Any, Optional

import requests

from lib.result import transport_error


def _parse_body(response: requests.Response) -> Any:
    if not response.content:
        return None
    try:
        return response.json()
    except ValueError:
        return response.text


def _request(method: str, url: str, headers: Optional[dict] = None, **kwargs) -> dict:
    try:
        resp = requests.request(method, url, headers=headers, timeout=60, **kwargs)
    except requests.RequestException as exc:
        return transport_error(str(exc))

    body = _parse_body(resp)
    if resp.status_code >= 400:
        return {"status_code": resp.status_code, "error": body if body is not None else "inaccessible"}
    return {"status_code": resp.status_code, "body": body}


def Get(url: str, headers: Optional[dict] = None, params: Optional[dict] = None) -> dict:
    return _request("GET", url, headers=headers, params=params)


def Post(
    url: str,
    json_body: Any = None,
    data: Any = None,
    headers: Optional[dict] = None,
) -> dict:
    hdrs = dict(headers or {})
    if json_body is not None and "Content-Type" not in hdrs:
        hdrs.setdefault("Content-Type", "application/json")
    return _request("POST", url, headers=hdrs, json=json_body, data=data)


def Put(url: str, json_body: Any = None, headers: Optional[dict] = None) -> dict:
    hdrs = dict(headers or {})
    if json_body is not None and "Content-Type" not in hdrs:
        hdrs.setdefault("Content-Type", "application/json")
    return _request("PUT", url, headers=hdrs, json=json_body)


def Delete(url: str, headers: Optional[dict] = None) -> dict:
    return _request("DELETE", url, headers=headers)
