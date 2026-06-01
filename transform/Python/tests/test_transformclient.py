"""Unit tests for transformclient."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import transformclient as tx


class TestJson:
    def test_parse_success(self):
        r = tx.JsonParse('{"a": 1}')
        assert r == {"status_code": 200, "data": {"a": 1}}

    def test_parse_error(self):
        r = tx.JsonParse("{bad")
        assert r["status_code"] == 400
        assert "error" in r

    def test_stringify_success(self):
        r = tx.JsonStringify({"x": "y"}, indent=2)
        assert r["status_code"] == 200
        assert '"x": "y"' in r["text"]

    def test_stringify_error(self):
        r = tx.JsonStringify({1, 2})
        assert r["status_code"] == 400


class TestCsv:
    def test_to_rows(self):
        r = tx.CsvToRows("id,name\n1,Ada\n")
        assert r["status_code"] == 200
        assert r["rows"] == [{"id": "1", "name": "Ada"}]

    def test_rows_to_csv(self):
        r = tx.RowsToCsv([{"id": "1", "name": "Ada"}])
        assert r["status_code"] == 200
        assert "id,name" in r["text"]

    def test_rows_to_csv_empty(self):
        assert tx.RowsToCsv([])["status_code"] == 400


class TestXml:
    def test_to_dict_and_back(self):
        xml_in = "<root><item>ok</item></root>"
        parsed = tx.XmlToDict(xml_in)
        assert parsed["status_code"] == 200
        data = parsed["data"]["root"]
        rebuilt = tx.DictToXml({"item": data["item"]}, "root")
        assert rebuilt["status_code"] == 200
        assert "item" in rebuilt["text"]

    def test_parse_error(self):
        assert tx.XmlToDict("<root")["status_code"] == 400
