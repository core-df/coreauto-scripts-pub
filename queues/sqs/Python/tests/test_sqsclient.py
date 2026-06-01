import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import sqsclient


@pytest.fixture(autouse=True)
def env(monkeypatch):
    monkeypatch.setenv("AWS_ACCESS_KEY_ID", "k")
    monkeypatch.setenv("SQS_QUEUE_URL", "https://sqs.aws/queue")


def test_init_missing_bucket(monkeypatch):
    monkeypatch.delenv("SQS_QUEUE_URL", raising=False)
    assert sqsclient.Init()["status_code"] == 601


@patch("sqsclient._client")
def test_send(mock_client):
    c = MagicMock()
    mock_client.return_value = c
    c.send_message.return_value = {"MessageId": "mid-1"}
    r = sqsclient.Send({"x": 1})
    assert r == {"status_code": 200, "message_id": "mid-1"}
