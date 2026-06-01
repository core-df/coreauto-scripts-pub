"""Unit tests for httpclient."""

from unittest.mock import patch

import requests

import httpclient

from conftest import make_response


@patch("httpclient.requests.request")
def test_get_success(mock_req):
    mock_req.return_value = make_response(200, {"ok": True})

    r = httpclient.Get("https://api.example/items", params={"q": "1"})

    assert r == {"status_code": 200, "body": {"ok": True}}
    assert mock_req.call_args[1]["params"] == {"q": "1"}


@patch("httpclient.requests.request")
def test_post_json(mock_req):
    mock_req.return_value = make_response(201, {"id": 1})

    r = httpclient.Post("https://api.example/items", json_body={"name": "x"})

    assert r["status_code"] == 201
    assert mock_req.call_args[0][0] == "POST"


@patch("httpclient.requests.request")
def test_http_error(mock_req):
    mock_req.return_value = make_response(404, {"detail": "missing"})

    r = httpclient.Get("https://api.example/missing")

    assert r["status_code"] == 404
    assert r["error"] == {"detail": "missing"}


@patch("httpclient.requests.request")
def test_transport_error(mock_req):
    mock_req.side_effect = requests.Timeout("timed out")

    r = httpclient.Delete("https://api.example/x")

    assert r["status_code"] == 0
    assert "timed out" in r["error"]
