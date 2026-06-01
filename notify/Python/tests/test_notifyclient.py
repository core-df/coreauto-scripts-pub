"""Unit tests for notifyclient (Slack, Teams, email, PagerDuty)."""

import smtplib
from unittest.mock import MagicMock, patch

import requests

import notifyclient

from conftest import make_response


class TestSlack:
    def test_missing_webhook_returns_601(self):
        result = notifyclient.Slack("hello")

        assert result == {
            "status_code": 601,
            "error": "Environment variables SLACK_WEBHOOK_URL should be defined",
        }

    @patch("notifyclient.requests.post")
    def test_success_with_explicit_url(self, mock_post, monkeypatch):
        mock_post.return_value = make_response(200)
        monkeypatch.delenv("SLACK_WEBHOOK_URL", raising=False)

        result = notifyclient.Slack("hello", webhook_url="https://hooks.slack.com/x")

        assert result == {"status_code": 200}
        mock_post.assert_called_once_with(
            "https://hooks.slack.com/x",
            json={"text": "hello"},
            timeout=30,
        )

    @patch("notifyclient.requests.post")
    def test_success_from_env(self, mock_post, monkeypatch):
        mock_post.return_value = make_response(200)
        monkeypatch.setenv("SLACK_WEBHOOK_URL", "https://hooks.slack.com/env")

        result = notifyclient.Slack("ping")

        assert result == {"status_code": 200}
        mock_post.assert_called_once_with(
            "https://hooks.slack.com/env",
            json={"text": "ping"},
            timeout=30,
        )

    @patch("notifyclient.requests.post")
    def test_http_error(self, mock_post):
        mock_post.return_value = make_response(400, text="invalid_payload")

        result = notifyclient.Slack("x", webhook_url="https://hooks.slack.com/x")

        assert result == {"status_code": 400, "error": "invalid_payload"}

    @patch("notifyclient.requests.post")
    def test_transport_error(self, mock_post):
        mock_post.side_effect = requests.ConnectionError("refused")

        result = notifyclient.Slack("x", webhook_url="https://hooks.slack.com/x")

        assert result["status_code"] == 0
        assert "refused" in result["error"]


class TestTeams:
    def test_missing_webhook_returns_601(self):
        result = notifyclient.Teams("alert")

        assert result == {
            "status_code": 601,
            "error": "Environment variables TEAMS_WEBHOOK_URL should be defined",
        }

    @patch("notifyclient.requests.post")
    def test_success_message_card_payload(self, mock_post):
        mock_post.return_value = make_response(200)

        result = notifyclient.Teams("alert", webhook_url="https://teams.example/webhook")

        assert result == {"status_code": 200}
        mock_post.assert_called_once()
        assert mock_post.call_args[1]["json"] == {
            "@type": "MessageCard",
            "@context": "http://schema.org/extensions",
            "text": "alert",
        }

    @patch("notifyclient.requests.post")
    def test_http_error(self, mock_post):
        mock_post.return_value = make_response(403, text="forbidden")

        result = notifyclient.Teams("x", webhook_url="https://teams.example/h")

        assert result == {"status_code": 403, "error": "forbidden"}


class TestEmail:
    def test_missing_smtp_config_returns_601(self):
        result = notifyclient.Email("Subj", "body", "ops@example.com")

        assert result == {
            "status_code": 601,
            "error": "Environment variables SMTP_HOST and SMTP_FROM (or from_addr) should be defined",
        }

    @patch("notifyclient.smtplib.SMTP")
    def test_success_without_auth(self, mock_smtp, monkeypatch):
        smtp_instance = MagicMock()
        mock_smtp.return_value.__enter__.return_value = smtp_instance
        monkeypatch.setenv("SMTP_HOST", "smtp.example.com")
        monkeypatch.setenv("SMTP_PORT", "25")
        monkeypatch.setenv("SMTP_FROM", "alerts@example.com")

        result = notifyclient.Email("Subj", "body text", "a@x.com, b@y.com")

        assert result == {"status_code": 200}
        mock_smtp.assert_called_once_with("smtp.example.com", 25, timeout=60)
        smtp_instance.starttls.assert_not_called()
        smtp_instance.login.assert_not_called()
        smtp_instance.sendmail.assert_called_once()
        recipients = smtp_instance.sendmail.call_args[0][1]
        assert recipients == ["a@x.com", "b@y.com"]

    @patch("notifyclient.smtplib.SMTP")
    def test_success_with_auth(self, mock_smtp, monkeypatch):
        smtp_instance = MagicMock()
        mock_smtp.return_value.__enter__.return_value = smtp_instance
        monkeypatch.setenv("SMTP_HOST", "smtp.example.com")
        monkeypatch.setenv("SMTP_USER", "user")
        monkeypatch.setenv("SMTP_PASSWORD", "pass")
        monkeypatch.setenv("SMTP_FROM", "alerts@example.com")

        result = notifyclient.Email("Subj", "body", "ops@example.com")

        assert result == {"status_code": 200}
        smtp_instance.starttls.assert_called_once()
        smtp_instance.login.assert_called_once_with("user", "pass")

    @patch("notifyclient.smtplib.SMTP")
    def test_from_addr_override(self, mock_smtp, monkeypatch):
        smtp_instance = MagicMock()
        mock_smtp.return_value.__enter__.return_value = smtp_instance
        monkeypatch.setenv("SMTP_HOST", "smtp.example.com")
        monkeypatch.setenv("SMTP_FROM", "ignored@example.com")

        notifyclient.Email("Subj", "body", "to@example.com", from_addr="custom@example.com")

        assert smtp_instance.sendmail.call_args[0][0] == "custom@example.com"

    @patch("notifyclient.smtplib.SMTP")
    def test_smtp_exception_returns_transport_error(self, mock_smtp, monkeypatch):
        mock_smtp.return_value.__enter__.side_effect = smtplib.SMTPException("relay denied")
        monkeypatch.setenv("SMTP_HOST", "smtp.example.com")
        monkeypatch.setenv("SMTP_FROM", "a@b.com")

        result = notifyclient.Email("Subj", "body", "to@example.com")

        assert result["status_code"] == 0
        assert "relay denied" in result["error"]


class TestPagerDuty:
    def test_missing_routing_key_returns_601(self):
        result = notifyclient.PagerDuty("incident")

        assert result == {
            "status_code": 601,
            "error": "Environment variables PAGERDUTY_ROUTING_KEY should be defined",
        }

    @patch("notifyclient.requests.post")
    def test_success(self, mock_post):
        mock_post.return_value = make_response(
            202,
            json_data={"status": "success", "message": "Event processed"},
        )

        result = notifyclient.PagerDuty(
            "Pipeline failed",
            routing_key="routing-key-abc",
            severity="warning",
        )

        assert result == {
            "status_code": 200,
            "body": {"status": "success", "message": "Event processed"},
        }
        mock_post.assert_called_once()
        assert mock_post.call_args[0][0] == "https://events.pagerduty.com/v2/enqueue"
        payload = mock_post.call_args[1]["json"]
        assert payload["routing_key"] == "routing-key-abc"
        assert payload["event_action"] == "trigger"
        assert payload["payload"]["summary"] == "Pipeline failed"
        assert payload["payload"]["severity"] == "warning"
        assert payload["payload"]["source"] == "coreauto-step"

    @patch("notifyclient.requests.post")
    def test_success_from_env(self, mock_post, monkeypatch):
        mock_post.return_value = make_response(202, json_data={"status": "ok"})
        monkeypatch.setenv("PAGERDUTY_ROUTING_KEY", "env-key")

        result = notifyclient.PagerDuty("alert")

        assert result["status_code"] == 200
        assert mock_post.call_args[1]["json"]["routing_key"] == "env-key"

    @patch("notifyclient.requests.post")
    def test_http_error(self, mock_post):
        mock_post.return_value = make_response(400, text="bad request")

        result = notifyclient.PagerDuty("x", routing_key="key")

        assert result == {"status_code": 400, "error": "bad request"}

    @patch("notifyclient.requests.post")
    def test_transport_error(self, mock_post):
        mock_post.side_effect = requests.Timeout("timed out")

        result = notifyclient.PagerDuty("x", routing_key="key")

        assert result["status_code"] == 0
        assert "timed out" in result["error"]
