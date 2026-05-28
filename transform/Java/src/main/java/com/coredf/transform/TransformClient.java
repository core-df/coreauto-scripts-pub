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

package com.coredf.transform;
import org.w3c.dom.*; import javax.xml.parsers.*; import javax.xml.transform.*; import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult; import java.io.*; import java.util.*;

public final class TransformClient {
    private TransformClient() {}
    public static Result JsonParse(String text) {
        try { return Result.ok(Map.of("data", JsonUtil.parse(text))); } catch (Exception e) { return Result.error(400, e.getMessage()); }
    }
    public static Result JsonStringify(Object data, Integer indent) {
        try {
            String s = JsonUtil.stringify(data);
            return Result.ok(Map.of("text", s));
        } catch (Exception e) { return Result.error(400, e.getMessage()); }
    }
    public static Result JsonStringify(Object data) { return JsonStringify(data, null); }
    public static Result CsvToRows(String text, String delimiter) {
        try {
            List<Map<String, String>> rows = new ArrayList<>(); String[] lines = text.split("\r?\n");
            if (lines.length == 0) return Result.ok(Map.of("rows", rows));
            String[] headers = lines[0].split(delimiter, -1);
            for (int i = 1; i < lines.length; i++) {
                if (lines[i].isEmpty()) continue; String[] cols = lines[i].split(delimiter, -1);
                Map<String, String> row = new LinkedHashMap<>(); for (int j = 0; j < headers.length; j++) row.put(headers[j], j < cols.length ? cols[j] : "");
                rows.add(row);
            }
            return Result.ok(Map.of("rows", rows));
        } catch (Exception e) { return Result.error(400, e.getMessage()); }
    }
    public static Result CsvToRows(String text) { return CsvToRows(text, ","); }
    public static Result RowsToCsv(List<Map<String, String>> rows, String delimiter) {
        if (rows == null || rows.isEmpty()) return Result.error(400, "rows must not be empty");
        try {
            List<String> headers = new ArrayList<>(rows.get(0).keySet()); StringBuilder sb = new StringBuilder(String.join(delimiter, headers)).append("\n");
            for (Map<String, String> row : rows) { List<String> vals = new ArrayList<>(); for (String h : headers) vals.add(row.getOrDefault(h, "")); sb.append(String.join(delimiter, vals)).append("\n"); }
            return Result.ok(Map.of("text", sb.toString()));
        } catch (Exception e) { return Result.error(400, e.getMessage()); }
    }
    public static Result RowsToCsv(List<Map<String, String>> rows) { return RowsToCsv(rows, ","); }
    public static Result XmlToDict(String text) {
        try { Document doc = DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(new ByteArrayInputStream(text.getBytes()));
            Element root = doc.getDocumentElement(); return Result.ok(Map.of("data", Map.of(root.getTagName(), elem(root)))); }
        catch (Exception e) { return Result.error(400, e.getMessage()); }
    }
    public static Result DictToXml(Map<String, Object> data, String rootTag) {
        try { Document doc = DocumentBuilderFactory.newInstance().newDocumentBuilder().newDocument();
            Element root = doc.createElement(rootTag); doc.appendChild(root);
            for (Map.Entry<String, Object> e : data.entrySet()) build(root, e.getValue(), e.getKey());
            Transformer t = TransformerFactory.newInstance().newTransformer();
            StringWriter sw = new StringWriter(); t.transform(new DOMSource(doc), new StreamResult(sw));
            return Result.ok(Map.of("text", sw.toString()));
        } catch (Exception e) { return Result.error(400, e.getMessage()); }
    }
    public static Result DictToXml(Map<String, Object> data) { return DictToXml(data, "root"); }
    private static Object elem(Element node) {
        NodeList children = node.getChildNodes(); boolean hasElem = false;
        for (int i = 0; i < children.getLength(); i++) if (children.item(i) instanceof Element) { hasElem = true; break; }
        if (!hasElem) return node.getTextContent() == null ? "" : node.getTextContent().trim();
        Map<String, Object> out = new LinkedHashMap<>();
        for (int i = 0; i < children.getLength(); i++) {
            if (!(children.item(i) instanceof Element child)) continue;
            Object val = elem(child); String tag = child.getTagName();
            if (out.containsKey(tag)) { Object prev = out.get(tag); if (!(prev instanceof List)) { List<Object> l = new ArrayList<>(); l.add(prev); out.put(tag, l); }
                ((List<Object>) out.get(tag)).add(val); } else out.put(tag, val);
        }
        return out;
    }
    @SuppressWarnings("unchecked")
    private static void build(Element parent, Object obj, String tag) {
        if (obj instanceof Map) { Element node = parent.getOwnerDocument().createElement(tag); parent.appendChild(node);
            for (Map.Entry<String, Object> e : ((Map<String, Object>) obj).entrySet()) build(node, e.getValue(), e.getKey()); }
        else if (obj instanceof List) { for (Object item : (List<?>) obj) build(parent, item, tag); }
        else { Element node = parent.getOwnerDocument().createElement(tag); node.setTextContent(obj == null ? "" : String.valueOf(obj)); parent.appendChild(node); }
    }
}
