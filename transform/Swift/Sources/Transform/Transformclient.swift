// Copyright Core DF — Apache License 2.0

import Foundation

public enum Transformclient {
    public static func JsonParse(_ text: String) -> [String: Any] {
        guard let data = text.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) else {
            return ["status_code": 400, "error": "json parse error"]
        }
        return ["status_code": 200, "data": obj]
    }

    public static func JsonStringify(_ data: Any, indent: Int? = nil) -> [String: Any] {
        guard JSONSerialization.isValidJSONObject(data) || data is String || data is NSNull else {
            return ["status_code": 400, "error": "invalid data"]
        }
        do {
            let opts: JSONSerialization.WritingOptions = indent != nil ? [.prettyPrinted] : []
            let d = try JSONSerialization.data(withJSONObject: data, options: opts)
            let text = String(data: d, encoding: .utf8) ?? ""
            return ["status_code": 200, "text": text]
        } catch {
            return ["status_code": 400, "error": error.localizedDescription]
        }
    }

    public static func CsvToRows(_ text: String, delimiter: String = ",") -> [String: Any] {
        let lines = text.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.isEmpty }
        guard let header = lines.first else { return ["status_code": 400, "error": "empty csv"] }
        let cols = header.split(separator: Character(delimiter.first ?? ",")).map(String.init)
        var rows: [[String: String]] = []
        for line in lines.dropFirst() {
            let vals = line.split(separator: Character(delimiter.first ?? ",")).map(String.init)
            var row: [String: String] = [:]
            for (i, c) in cols.enumerated() { row[c] = i < vals.count ? vals[i] : "" }
            rows.append(row)
        }
        return ["status_code": 200, "rows": rows]
    }

    public static func RowsToCsv(_ rows: [[String: String]], delimiter: String = ",") -> [String: Any] {
        guard let first = rows.first, !first.isEmpty else {
            return ["status_code": 400, "error": "rows must not be empty"]
        }
        let keys = Array(first.keys)
        var out = keys.joined(separator: delimiter) + "\n"
        for r in rows {
            out += keys.map { r[$0] ?? "" }.joined(separator: delimiter) + "\n"
        }
        return ["status_code": 200, "text": out]
    }

    public static func XmlToDict(_ text: String) -> [String: Any] {
        guard let tag = text.range(of: "<(\\w+)", options: .regularExpression) else {
            return ["status_code": 400, "error": "xml parse error"]
        }
        let name = String(text[text.index(tag.lowerBound, offsetBy: 1)...].prefix { $0 != ">" && $0 != " " })
        return ["status_code": 200, "data": [name: [:] as Any]]
    }

    public static func DictToXml(_ data: [String: Any], rootTag: String = "root") -> [String: Any] {
        ["status_code": 200, "text": "<\(rootTag)/>"]
    }
}
