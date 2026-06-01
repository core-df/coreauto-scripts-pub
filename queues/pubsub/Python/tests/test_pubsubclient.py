import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import pubsubclient


@pytest.fixture(autouse=True)
def env(monkeypatch):
    monkeypatch.setenv("PUBSUB_PROJECT_ID", "proj")
    monkeypatch.setenv("PUBSUB_TOPIC_ID", "topic")


def test_init_missing(monkeypatch):
    monkeypatch.delenv("PUBSUB_PROJECT_ID", raising=False)
    monkeypatch.delenv("GOOGLE_CLOUD_PROJECT", raising=False)
    assert pubsubclient.Init()["status_code"] == 601


def test_publish():
    mock_pubsub = MagicMock()
    pub = MagicMock()
    mock_pubsub.PublisherClient.return_value = pub
    pub.publish.return_value.result.return_value = "mid"
    google_mod = MagicMock()
    google_mod.cloud.pubsub_v1 = mock_pubsub
    with patch.dict(sys.modules, {"google": google_mod, "google.cloud": google_mod.cloud}):
        r = pubsubclient.Publish({"x": 1})
    assert r["status_code"] == 200
