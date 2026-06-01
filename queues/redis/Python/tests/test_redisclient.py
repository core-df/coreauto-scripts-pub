import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import redisclient


@pytest.fixture(autouse=True)
def env(monkeypatch):
    monkeypatch.setenv("REDIS_HOST", "redis.local")


def test_init_missing(monkeypatch):
    monkeypatch.delenv("REDIS_HOST", raising=False)
    monkeypatch.delenv("REDIS_URL", raising=False)
    assert redisclient.Init()["status_code"] == 601


@patch("redisclient._client")
def test_push(mock_client_fn):
    c = MagicMock()
    mock_client_fn.return_value = c
    assert redisclient.Push("q", "v") == {"status_code": 200}
