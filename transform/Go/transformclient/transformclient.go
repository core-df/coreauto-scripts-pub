// Copyright Core DF
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// JSON, CSV, and XML transform helpers for Core Auto step scripts.

package transformclient

import (
	"bytes"
	"encoding/csv"
	"encoding/json"
	"encoding/xml"
	"fmt"
	"strings"

	"github.com/core-df/coreauto-scripts-pub/transform/Go/internal/result"
)

// JsonParse parses a JSON string into a Go value.
func JsonParse(text string) result.Result {
	var data any
	if err := json.Unmarshal([]byte(text), &data); err != nil {
		return result.Result{StatusCode: 400, Error: err.Error()}
	}
	return result.Result{StatusCode: 200, Data: data}
}

// JsonStringify serializes data to a JSON string.
func JsonStringify(data any, indent *int) result.Result {
	var out []byte
	var err error
	if indent != nil {
		out, err = json.MarshalIndent(data, "", strings.Repeat(" ", *indent))
	} else {
		out, err = json.Marshal(data)
	}
	if err != nil {
		return result.Result{StatusCode: 400, Error: err.Error()}
	}
	return result.Result{StatusCode: 200, Text: string(out)}
}

// CsvToRows parses CSV text into a slice of row maps.
func CsvToRows(text string, delimiter string) result.Result {
	if delimiter == "" {
		delimiter = ","
	}
	r := csv.NewReader(strings.NewReader(text))
	r.Comma = rune(delimiter[0])
	records, err := r.ReadAll()
	if err != nil {
		return result.Result{StatusCode: 400, Error: err.Error()}
	}
	if len(records) == 0 {
		return result.Result{StatusCode: 200, Rows: []map[string]string{}}
	}
	header := records[0]
	rows := make([]map[string]string, 0, len(records)-1)
	for _, rec := range records[1:] {
		row := make(map[string]string, len(header))
		for i, col := range header {
			if i < len(rec) {
				row[col] = rec[i]
			} else {
				row[col] = ""
			}
		}
		rows = append(rows, row)
	}
	return result.Result{StatusCode: 200, Rows: rows}
}

// RowsToCsv serializes row maps to CSV text.
func RowsToCsv(rows []map[string]string, delimiter string) result.Result {
	if len(rows) == 0 {
		return result.Result{StatusCode: 400, Error: "rows must not be empty"}
	}
	if delimiter == "" {
		delimiter = ","
	}
	var buf bytes.Buffer
	w := csv.NewWriter(&buf)
	w.Comma = rune(delimiter[0])

	fieldnames := make([]string, 0, len(rows[0]))
	for k := range rows[0] {
		fieldnames = append(fieldnames, k)
	}
	if err := w.Write(fieldnames); err != nil {
		return result.Result{StatusCode: 400, Error: err.Error()}
	}
	for _, row := range rows {
		record := make([]string, len(fieldnames))
		for i, col := range fieldnames {
			record[i] = row[col]
		}
		if err := w.Write(record); err != nil {
			return result.Result{StatusCode: 400, Error: err.Error()}
		}
	}
	w.Flush()
	if err := w.Error(); err != nil {
		return result.Result{StatusCode: 400, Error: err.Error()}
	}
	return result.Result{StatusCode: 200, Text: buf.String()}
}

type xmlNode struct {
	XMLName  xml.Name
	Content  string     `xml:",chardata"`
	Children []xmlNode  `xml:",any"`
	Attrs    []xml.Attr `xml:",any,attr"`
}

// XmlToDict parses XML text into a nested map keyed by root tag.
func XmlToDict(text string) result.Result {
	dec := xml.NewDecoder(strings.NewReader(text))
	var root xmlNode
	if err := dec.Decode(&root); err != nil {
		return result.Result{StatusCode: 400, Error: err.Error()}
	}
	data := map[string]any{root.XMLName.Local: elemToValue(root)}
	return result.Result{StatusCode: 200, Data: data}
}

func elemToValue(node xmlNode) any {
	if len(node.Children) == 0 {
		return strings.TrimSpace(node.Content)
	}
	out := make(map[string]any)
	for _, child := range node.Children {
		val := elemToValue(child)
		tag := child.XMLName.Local
		if existing, ok := out[tag]; ok {
			switch v := existing.(type) {
			case []any:
				out[tag] = append(v, val)
			default:
				out[tag] = []any{v, val}
			}
		} else {
			out[tag] = val
		}
	}
	return out
}

// DictToXml builds XML text from a map with the given root tag.
func DictToXml(data map[string]any, rootTag string) result.Result {
	if rootTag == "" {
		rootTag = "root"
	}
	root := &xmlElement{Name: rootTag}
	for k, v := range data {
		buildElement(root, v, k)
	}
	var buf bytes.Buffer
	buf.WriteString(xml.Header)
	enc := xml.NewEncoder(&buf)
	if err := enc.Encode(root); err != nil {
		return result.Result{StatusCode: 400, Error: err.Error()}
	}
	text := strings.TrimSpace(buf.String())
	if strings.HasPrefix(text, "<?xml") {
		if idx := strings.Index(text, "?>"); idx >= 0 {
			text = strings.TrimSpace(text[idx+2:])
		}
	}
	return result.Result{StatusCode: 200, Text: text}
}

type xmlElement struct {
	XMLName  xml.Name
	Name     string       `xml:"-"`
	Content  string       `xml:",chardata"`
	Children []*xmlElement `xml:",any"`
}

func (e *xmlElement) MarshalXML(enc *xml.Encoder, start xml.StartElement) error {
	tag := e.Name
	if tag == "" {
		tag = e.XMLName.Local
	}
	start.Name = xml.Name{Local: tag}
	if err := enc.EncodeToken(start); err != nil {
		return err
	}
	if len(e.Children) == 0 {
		if err := enc.EncodeToken(xml.CharData(e.Content)); err != nil {
			return err
		}
	} else {
		for _, child := range e.Children {
			if err := enc.Encode(child); err != nil {
				return err
			}
		}
	}
	return enc.EncodeToken(start.End())
}

func buildElement(parent *xmlElement, obj any, tag string) {
	switch v := obj.(type) {
	case map[string]any:
		node := &xmlElement{Name: tag}
		parent.Children = append(parent.Children, node)
		for k, val := range v {
			buildElement(node, val, k)
		}
	case []any:
		for _, item := range v {
			buildElement(parent, item, tag)
		}
	default:
		text := ""
		if obj != nil {
			text = fmt.Sprint(obj)
		}
		parent.Children = append(parent.Children, &xmlElement{Name: tag, Content: text})
	}
}
