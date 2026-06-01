import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import rabbitclient


@pytest.fixture(autouse=True)
def env(monkeypatch):
    monkeypatch.setenv("RABBITMQ_HOST", "rabbit.local")


def test_init_missing(monkeypatch):
    monkeypatch.delenv("RABBITMQ_HOST", raising=False)
    monkeypatch.delenv("RABBITMQ_URL", raising=False)
    assert rabbitclient.Init()["status_code"] == 601


def test_publish():
    mock_pika = MagicMock()
    conn = MagicMock()
    ch = MagicMock()
    mock_pika.BlockingConnection.return_value = conn
    mock_pika.URLParameters.return_value = object()
    conn.channel.return_value = ch
    with patch.dict(sys.modules, {"pika": mock_pika}):
        r = rabbitclient.Publish("q", {"n": 1})
    assert r == {"status_code": 200}
