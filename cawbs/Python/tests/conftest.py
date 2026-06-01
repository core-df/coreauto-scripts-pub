"""Shared fixtures for cawbs Python unit tests."""

import sys
from pathlib import Path
from unittest.mock import Mock

import pytest

# Import modules from cawbs/Python (parent of tests/).
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

RT_ENV = {
    "ENV": "dev",
    "ACTIONID": "99",
    "CA_ACCESS_CODE": "secret",
    "CA_WBS_URL": "http://collector.example/",
    "STEPNAME": "EnrichOrder",
}

BATCH_ENV = {
    "ENV": "dev",
    "CA_ACCESS_CODE": "secret",
    "CA_WBS_URL": "http://collector.example",
}

INGRESS_ENV = BATCH_ENV


def make_response(status_code=200, json_data=None, json_raises=False):
    """Build a mock requests.Response."""
    resp = Mock()
    resp.status_code = status_code
    if json_raises:
        resp.json.side_effect = ValueError("not json")
    else:
        resp.json.return_value = json_data if json_data is not None else {}
    return resp


def configure_rt(module, *, initialized=False, url=None):
    """Set cawbs module globals for real-time client tests."""
    module.wbs_env = RT_ENV["ENV"]
    module.wbs_actionid = RT_ENV["ACTIONID"]
    module.wbs_accesscode = RT_ENV["CA_ACCESS_CODE"]
    module.wbs_url = url if url is not None else RT_ENV["CA_WBS_URL"]
    module.wbs_step = RT_ENV["STEPNAME"]
    module.wbs_iniflag = initialized
    module.wbs_headers = (
        {
            "Content-Type": "application/json",
            "Environment": RT_ENV["ENV"],
            "Authorization": "Bearer test-token",
        }
        if initialized
        else {}
    )


def configure_batch(module, *, initialized=False, url=None):
    """Set cawbsbatch module globals."""
    module.wbs_env = BATCH_ENV["ENV"]
    module.wbs_accesscode = BATCH_ENV["CA_ACCESS_CODE"]
    module.wbs_url = url if url is not None else BATCH_ENV["CA_WBS_URL"]
    module.wbs_iniflag = initialized
    module.wbs_headers = (
        {
            "Content-Type": "application/json",
            "Environment": BATCH_ENV["ENV"],
            "Authorization": "Bearer test-token",
        }
        if initialized
        else {}
    )


def configure_ingress(module, *, initialized=False, url=None):
    """Set cawbsingress module globals."""
    module.wbs_env = INGRESS_ENV["ENV"]
    module.wbs_accesscode = INGRESS_ENV["CA_ACCESS_CODE"]
    module.wbs_url = url if url is not None else INGRESS_ENV["CA_WBS_URL"]
    module.wbs_iniflag = initialized
    module.wbs_headers = (
        {
            "Content-Type": "application/json",
            "Environment": INGRESS_ENV["ENV"],
            "Authorization": "Bearer test-token",
        }
        if initialized
        else {}
    )


@pytest.fixture(autouse=True)
def _isolate_modules():
    """Reset module state before and after each test."""
    import cawbs
    import cawbsbatch
    import cawbsingress

    configure_rt(cawbs, initialized=False)
    configure_batch(cawbsbatch, initialized=False)
    configure_ingress(cawbsingress, initialized=False)
    yield
    configure_rt(cawbs, initialized=False)
    configure_batch(cawbsbatch, initialized=False)
    configure_ingress(cawbsingress, initialized=False)
