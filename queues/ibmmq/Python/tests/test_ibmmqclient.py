import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import ibmmqclient


@pytest.fixture(autouse=True)
def env(monkeypatch):
    monkeypatch.setenv("MQ_HOST", "mq.local")
    monkeypatch.setenv("MQ_QUEUE_MANAGER", "QM1")
    monkeypatch.setenv("MQ_QUEUE", "DEV.QUEUE")


def test_init_missing_host(monkeypatch):
    monkeypatch.delenv("MQ_HOST", raising=False)
    assert ibmmqclient.Init()["status_code"] == 601


def test_put():
    mock_pymqi = MagicMock()
    qmgr = MagicMock()
    queue = MagicMock()
    mock_pymqi.connect.return_value = qmgr
    mock_pymqi.Queue.return_value = queue
    mock_pymqi.CMQC = MagicMock()
    mock_pymqi.CMQC.MQCHT_CLNT = 1
    mock_pymqi.CMQC.MQXPT_TCP = 2
    mock_pymqi.CD.return_value = MagicMock()
    with patch.dict(sys.modules, {"pymqi": mock_pymqi}):
        r = ibmmqclient.Put({"id": 1})
    assert r == {"status_code": 200}
