"""Shared fixtures for notify Python unit tests."""

import sys
from pathlib import Path
from unittest.mock import Mock

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))


def make_response(status_code=200, text="", json_data=None, json_raises=False):
    """Build a mock requests.Response."""
    resp = Mock()
    resp.status_code = status_code
    resp.text = text
    if json_raises:
        resp.json.side_effect = ValueError("not json")
    else:
        resp.json.return_value = json_data if json_data is not None else {}
    return resp


@pytest.fixture(autouse=True)
def _clear_notify_env(monkeypatch):
    """Unset notify-related env vars so tests control configuration."""
    for key in (
        "SLACK_WEBHOOK_URL",
        "TEAMS_WEBHOOK_URL",
        "SMTP_HOST",
        "SMTP_PORT",
        "SMTP_USER",
        "SMTP_PASSWORD",
        "SMTP_FROM",
        "PAGERDUTY_ROUTING_KEY",
    ):
        monkeypatch.delenv(key, raising=False)
    yield
