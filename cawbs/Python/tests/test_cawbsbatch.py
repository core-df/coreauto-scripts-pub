"""Unit tests for cawbsbatch (batch Collector client)."""

from unittest.mock import patch

import cawbsbatch

from conftest import configure_batch, make_response


class TestCawbsbatchInit:
    def test_missing_env_returns_601(self):
        configure_batch(cawbsbatch)
        cawbsbatch.wbs_url = None

        result = cawbsbatch.Init()

        assert result == {
            "status_code": 601,
            "error": "Environment variables ENV, CA_ACCESS_CODE, CA_WBS_URL should be defined",
        }

    @patch("cawbsbatch.requests.post")
    def test_success(self, mock_post):
        configure_batch(cawbsbatch)
        mock_post.return_value = make_response(200, {"token": "batch-tok"})

        result = cawbsbatch.Init()

        assert result == {"status_code": 200}
        assert cawbsbatch.wbs_headers["Authorization"] == "Bearer batch-tok"

    @patch("cawbsbatch.requests.post")
    def test_double_init_returns_602(self, mock_post):
        configure_batch(cawbsbatch)
        mock_post.return_value = make_response(200, {"token": "x"})

        cawbsbatch.Init()
        assert cawbsbatch.Init() == {"status_code": 602, "error": "init already called"}


class TestCawbsbatchKeystore:
    def test_get_keystore_requires_init(self):
        configure_batch(cawbsbatch, initialized=False)

        assert cawbsbatch.GetKeystore("key") == {"status_code": 603, "error": "Init required"}

    @patch("cawbsbatch.requests.get")
    def test_get_keystore_success(self, mock_get):
        configure_batch(cawbsbatch, initialized=True)
        mock_get.return_value = make_response(200, {"secret": "value"})

        result = cawbsbatch.GetKeystore("secret")

        assert result == {"status_code": 200, "answer": {"secret": "value"}}
