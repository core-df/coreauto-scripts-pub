import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import ingress


def test_trigger_event_missing_name(monkeypatch):
    monkeypatch.delenv("CA_EVENT_NAME", raising=False)
    r = ingress.TriggerEvent({"x": 1})
    assert r["status_code"] == 601


@patch("ingress._load_cawbsingress")
def test_forward_messages(mock_load, monkeypatch):
    monkeypatch.setenv("CA_EVENT_NAME", "OrderCreated")
    cawbs = MagicMock()
    mock_load.return_value = cawbs
    cawbs.Init.return_value = {"status_code": 200}
    cawbs.PostEvent.return_value = {"status_code": 201, "actionId": 1, "eventId": 2}

    consume = {"status_code": 200, "messages": [{"value": {"order": 1}}]}
    r = ingress.ForwardMessages(consume)

    assert r["status_code"] == 200
    assert r["forwarded"] == [{"actionId": 1, "eventId": 2}]
