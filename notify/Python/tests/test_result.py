"""Unit tests for lib.result helpers."""

from lib.result import missing_env, transport_error


class TestMissingEnv:
    def test_returns_601(self):
        assert missing_env("SLACK_WEBHOOK_URL") == {
            "status_code": 601,
            "error": "Environment variables SLACK_WEBHOOK_URL should be defined",
        }


class TestTransportError:
    def test_default_message(self):
        assert transport_error() == {"status_code": 0, "error": "inaccessible"}

    def test_custom_message(self):
        assert transport_error("connection reset") == {
            "status_code": 0,
            "error": "connection reset",
        }
