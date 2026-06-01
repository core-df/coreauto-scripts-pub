import sys
from pathlib import Path
from unittest.mock import AsyncMock, patch

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import natsclient


@pytest.fixture(autouse=True)
def env(monkeypatch):
    monkeypatch.setenv("NATS_URL", "nats://localhost:4222")


def test_init_missing(monkeypatch):
    monkeypatch.delenv("NATS_URL", raising=False)
    monkeypatch.delenv("NATS_SERVERS", raising=False)
    assert natsclient.Init()["status_code"] == 601


@patch("natsclient.asyncio.run")
def test_publish(mock_run):
    mock_run.return_value = {"status_code": 200}
    assert natsclient.Publish("subj", {"a": 1}) == {"status_code": 200}
