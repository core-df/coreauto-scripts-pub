"""Unit tests for s3client."""

import sys
from io import BytesIO
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import s3client


@pytest.fixture(autouse=True)
def _env(monkeypatch):
    monkeypatch.setenv("AWS_ACCESS_KEY_ID", "key")
    monkeypatch.setenv("AWS_SECRET_ACCESS_KEY", "secret")
    monkeypatch.setenv("S3_BUCKET", "my-bucket")
    monkeypatch.delenv("AWS_PROFILE", raising=False)


def test_init_missing_credentials(monkeypatch):
    monkeypatch.delenv("AWS_ACCESS_KEY_ID", raising=False)
    monkeypatch.delenv("AWS_PROFILE", raising=False)
    r = s3client.Init()
    assert r["status_code"] == 601


def test_init_success():
    assert s3client.Init() == {"status_code": 200}


@patch("s3client._client")
def test_get_object(mock_client_fn):
    client = MagicMock()
    mock_client_fn.return_value = client
    client.get_object.return_value = {"Body": BytesIO(b"payload")}

    r = s3client.GetObject("path/key.txt")

    assert r == {"status_code": 200, "content": "payload"}


@patch("s3client._client")
def test_put_object(mock_client_fn):
    client = MagicMock()
    mock_client_fn.return_value = client

    r = s3client.PutObject("k", "data")

    assert r == {"status_code": 200}
    client.put_object.assert_called_once()


@patch("s3client._client")
def test_list_objects(mock_client_fn):
    client = MagicMock()
    mock_client_fn.return_value = client
    client.list_objects_v2.return_value = {"Contents": [{"Key": "a"}, {"Key": "b"}]}

    r = s3client.ListObjects(prefix="p/")

    assert r == {"status_code": 200, "keys": ["a", "b"]}


def test_get_object_missing_bucket(monkeypatch):
    monkeypatch.delenv("S3_BUCKET", raising=False)
    r = s3client.GetObject("k", bucket="")
    assert r["status_code"] == 601
