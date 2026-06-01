"""Unit tests for fileclient."""

import sys
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import fileclient


class TestLocal:
    def test_read_write_move(self, tmp_path):
        p = tmp_path / "a" / "f.txt"
        assert fileclient.LocalWrite(str(p), "hello") == {"status_code": 200}
        assert fileclient.LocalRead(str(p)) == {"status_code": 200, "content": "hello"}
        dest = tmp_path / "b" / "f.txt"
        dest.parent.mkdir(parents=True, exist_ok=True)
        assert fileclient.LocalMove(str(p), str(dest)) == {"status_code": 200}
        assert fileclient.LocalRead(str(dest))["content"] == "hello"

    def test_read_missing(self, tmp_path):
        r = fileclient.LocalRead(str(tmp_path / "nope.txt"))
        assert r["status_code"] == 500


class TestSftp:
    @patch("fileclient._sftp_connect")
    def test_get_success(self, mock_connect, tmp_path, monkeypatch):
        mock_sftp = MagicMock()
        mock_ssh = MagicMock()
        mock_connect.return_value = (mock_ssh, mock_sftp)
        monkeypatch.setenv("SFTP_HOST", "sftp.example")
        monkeypatch.setenv("SFTP_USER", "u")
        monkeypatch.setenv("SFTP_PASSWORD", "p")

        local = tmp_path / "out.bin"
        r = fileclient.SftpGet("/remote/x", str(local))

        assert r == {"status_code": 200}
        mock_sftp.get.assert_called_once()

    def test_connect_missing_env(self, monkeypatch):
        monkeypatch.delenv("SFTP_HOST", raising=False)
        monkeypatch.delenv("SFTP_USER", raising=False)
        r = fileclient.SftpList()
        assert r["status_code"] == 0
