import sys
from pathlib import Path
from unittest.mock import Mock

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))


def make_response(status_code=200, json_data=None, text=""):
    resp = Mock()
    resp.status_code = status_code
    resp.content = b"{}" if json_data is not None else text.encode()
    if json_data is not None:
        resp.json.return_value = json_data
    else:
        resp.json.side_effect = ValueError("not json")
    resp.text = text if text else (str(json_data) if json_data else "")
    return resp


@pytest.fixture(autouse=True)
def _no_real_http(monkeypatch):
    yield
