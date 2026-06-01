"""Unit tests for cawbs (real-time Collector client)."""

import json
from unittest.mock import patch

import cawbs

from conftest import RT_ENV, configure_rt, make_response


class TestInit:
    def test_missing_env_returns_601(self):
        configure_rt(cawbs)
        cawbs.wbs_step = None

        result = cawbs.Init()

        assert result == {
            "status_code": 601,
            "error": "Environment variables ENV, ACTIONID, CA_ACCESS_CODE, CA_WBS_URL, STEPNAME should be defined",
        }

    @patch("cawbs.requests.post")
    def test_success_sets_bearer_and_strips_url(self, mock_post):
        configure_rt(cawbs, url="http://collector.example///")
        mock_post.return_value = make_response(200, {"token": "abc"})

        result = cawbs.Init()

        assert result == {"status_code": 200}
        assert cawbs.wbs_iniflag is True
        assert cawbs.wbs_url == "http://collector.example"
        assert cawbs.wbs_headers["Authorization"] == "Bearer abc"
        mock_post.assert_called_once()
        call_url = mock_post.call_args[0][0]
        assert call_url == "http://collector.example/v1/auth/apicode"
        body = json.loads(mock_post.call_args[1]["data"])
        assert body == {"apiCode": RT_ENV["CA_ACCESS_CODE"]}

    @patch("cawbs.requests.post")
    def test_double_init_returns_602(self, mock_post):
        configure_rt(cawbs)
        mock_post.return_value = make_response(200, {"token": "abc"})

        assert cawbs.Init()["status_code"] == 200
        assert cawbs.Init() == {"status_code": 602, "error": "init already called"}
        mock_post.assert_called_once()

    @patch("cawbs.requests.post")
    def test_auth_http_error_with_json(self, mock_post):
        configure_rt(cawbs)
        mock_post.return_value = make_response(401, {"message": "invalid code"})

        result = cawbs.Init()

        assert result["status_code"] == 401
        assert result["error"] == {"message": "invalid code"}

    @patch("cawbs.requests.post")
    def test_auth_non_json_returns_inaccessible(self, mock_post):
        configure_rt(cawbs)
        mock_post.return_value = make_response(502, json_raises=True)

        result = cawbs.Init()

        assert result == {"status_code": 502, "error": "inaccessible"}


class TestBeforeInit:
    def test_get_event_payload_requires_init(self):
        configure_rt(cawbs, initialized=False)

        assert cawbs.GetEventPayload() == {"status_code": 603, "error": "Init required"}

    def test_put_step_payload_requires_init(self):
        configure_rt(cawbs, initialized=False)

        assert cawbs.PutStepPayload({}) == {"status_code": 603, "error": "Init required"}


class TestAfterInit:
    @patch("cawbs.requests.get")
    def test_get_event_payload_success(self, mock_get):
        configure_rt(cawbs, initialized=True, url="http://collector.example")
        mock_get.return_value = make_response(200, {"payload": {"orderId": "1"}})

        result = cawbs.GetEventPayload()

        assert result == {"status_code": 200, "payload": {"orderId": "1"}}
        mock_get.assert_called_once_with(
            "http://collector.example/v1/rtevent/99",
            headers=cawbs.wbs_headers,
        )

    @patch("cawbs.requests.post")
    def test_put_step_payload_success(self, mock_post):
        configure_rt(cawbs, initialized=True, url="http://collector.example")
        mock_post.return_value = make_response(200)

        result = cawbs.PutStepPayload({"done": True})

        assert result == {"status_code": 200}
        body = json.loads(mock_post.call_args[1]["data"])
        assert body == {
            "actionId": "99",
            "stepname": "EnrichOrder",
            "payload": {"done": True},
        }

    @patch("cawbs.requests.get")
    def test_get_keystore_missing_key_returns_605(self, mock_get):
        configure_rt(cawbs, initialized=True, url="http://collector.example")
        mock_get.return_value = make_response(200, {"db_user": "u1"})

        result = cawbs.GetKeystore("db_user, db_password")

        assert result == {"status_code": 605, "error": "db_password not found"}
        mock_get.assert_called_once_with(
            "http://collector.example/v1/keystore/db_user,db_password",
            headers=cawbs.wbs_headers,
        )

    @patch("cawbs.requests.get")
    def test_get_keystore_success_strips_spaces(self, mock_get):
        configure_rt(cawbs, initialized=True, url="http://collector.example")
        mock_get.return_value = make_response(200, {"a": "1", "b": "2"})

        result = cawbs.GetKeystore("a, b")

        assert result == {"status_code": 200, "answer": {"a": "1", "b": "2"}}
