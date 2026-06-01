import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import servicebusclient


@pytest.fixture(autouse=True)
def env(monkeypatch):
    monkeypatch.setenv("SERVICE_BUS_CONNECTION_STRING", "Endpoint=sb://x")
    monkeypatch.setenv("SERVICE_BUS_QUEUE_NAME", "q")


def test_init_missing(monkeypatch):
    monkeypatch.delenv("SERVICE_BUS_CONNECTION_STRING", raising=False)
    assert servicebusclient.Init()["status_code"] == 601


def test_send():
    mock_sb = MagicMock()
    client = MagicMock()
    sender = MagicMock()
    mock_sb.ServiceBusClient.from_connection_string.return_value.__enter__.return_value = client
    client.get_queue_sender.return_value.__enter__.return_value = sender
    with patch.dict(
        sys.modules,
        {"azure.servicebus": mock_sb, "azure": MagicMock()},
    ):
        r = servicebusclient.Send({"ok": True})
    assert r == {"status_code": 200}
