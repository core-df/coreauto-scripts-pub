"""Unit tests for cawbsingress (ingress Collector client)."""

import json
from unittest.mock import patch

import cawbsingress

from conftest import configure_ingress, make_response


class TestCawbsingressInit:
    def test_missing_env_returns_601(self):
        configure_ingress(cawbsingress)
        cawbsingress.wbs_accesscode = None

        result = cawbsingress.Init()

        assert result["status_code"] == 601
        assert "ENV, CA_ACCESS_CODE, CA_WBS_URL" in result["error"]


class TestCawbsingressPostEvent:
    def test_post_event_requires_init(self):
        configure_ingress(cawbsingress, initialized=False)

        assert cawbsingress.PostEvent("Evt", {}) == {
            "status_code": 603,
            "error": "Init required",
        }

    @patch("cawbsingress.requests.post")
    def test_post_event_success(self, mock_post):
        configure_ingress(cawbsingress, initialized=True)
        mock_post.return_value = make_response(
            201,
            {"eventId": 1, "actionId": 42, "createdAt": "2026-01-01T00:00:00Z"},
        )

        result = cawbsingress.PostEvent(
            "OrderCreated",
            {"orderId": "123"},
            event_source="kafka",
        )

        assert result == {
            "status_code": 201,
            "eventId": 1,
            "actionId": 42,
            "createdAt": "2026-01-01T00:00:00Z",
        }
        body = json.loads(mock_post.call_args[1]["data"])
        assert body == {
            "eventName": "OrderCreated",
            "payload": {"orderId": "123"},
            "eventSource": "kafka",
        }

    @patch("cawbsingress.requests.post")
    def test_submit_flag_success(self, mock_post):
        configure_ingress(cawbsingress, initialized=True)
        mock_post.return_value = make_response(200, {"status": "accepted"})

        result = cawbsingress.SubmitFlag("daily", "ERP", "SAP", "2026-06-01")

        assert result == {"status_code": 200, "flagStatus": "accepted"}
