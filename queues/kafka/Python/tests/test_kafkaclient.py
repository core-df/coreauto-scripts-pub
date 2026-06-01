import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import kafkaclient as client


@pytest.fixture(autouse=True)
def bootstrap(monkeypatch):
    monkeypatch.setattr(client, "_bootstrap", "localhost:9092")


def test_init_missing():
    client._bootstrap = ""
    assert client.Init()["status_code"] == 601
    client._bootstrap = "localhost:9092"


def test_init_ok():
    assert client.Init() == {"status_code": 200}


def test_produce():
    producer = MagicMock()
    mod = MagicMock()
    mod.Producer.return_value = producer
    with patch.dict(sys.modules, {"confluent_kafka": mod}):
        r = client.Produce("orders", {"id": 1}, key="k1")
    assert r == {"status_code": 200}
    producer.produce.assert_called_once()
