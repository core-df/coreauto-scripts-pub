package transformclient

import "testing"

func TestJsonParse_Success(t *testing.T) {
	r := JsonParse(`{"a":1}`)
	if r.StatusCode != 200 {
		t.Fatalf("%+v", r)
	}
}

func TestJsonParse_Error(t *testing.T) {
	if JsonParse("{").StatusCode != 400 {
		t.Fatal()
	}
}

func TestCsvRoundTrip(t *testing.T) {
	csv := "id,name\n1,Ada\n"
	rows := CsvToRows(csv, ",")
	if rows.StatusCode != 200 {
		t.Fatal(rows)
	}
	rowData, ok := rows.Rows.([]map[string]string)
	if !ok {
		t.Fatalf("rows type %T", rows.Rows)
	}
	out := RowsToCsv(rowData, ",")
	if out.StatusCode != 200 || out.Text == "" {
		t.Fatal(out)
	}
}

func TestRowsToCsv_Empty(t *testing.T) {
	if RowsToCsv(nil, ",").StatusCode != 400 {
		t.Fatal()
	}
}

func TestXmlRoundTrip(t *testing.T) {
	in := "<root><item>ok</item></root>"
	parsed := XmlToDict(in)
	if parsed.StatusCode != 200 {
		t.Fatal(parsed)
	}
	root, ok := parsed.Data.(map[string]any)["root"].(map[string]any)
	if !ok {
		t.Fatal(parsed.Data)
	}
	out := DictToXml(map[string]any{"item": root["item"]}, "root")
	if out.StatusCode != 200 {
		t.Fatal(out)
	}
}
