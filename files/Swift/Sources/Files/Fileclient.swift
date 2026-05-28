// Copyright Core DF — Apache License 2.0

import Foundation

public enum Fileclient {
    public static func LocalRead(_ path: String, encoding: String = "utf-8") -> [String: Any] {
        guard encoding.lowercased() == "utf-8" else {
            return ["status_code": 500, "error": "unsupported encoding: \(encoding)"]
        }
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            return ["status_code": 200, "content": content]
        } catch {
            return ["status_code": 500, "error": error.localizedDescription]
        }
    }

    public static func LocalWrite(_ path: String, content: String, encoding: String = "utf-8") -> [String: Any] {
        guard encoding.lowercased() == "utf-8" else {
            return ["status_code": 500, "error": "unsupported encoding: \(encoding)"]
        }
        let url = URL(fileURLWithPath: path)
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try content.write(to: url, atomically: true, encoding: .utf8)
            return ["status_code": 200]
        } catch {
            return ["status_code": 500, "error": error.localizedDescription]
        }
    }

    public static func LocalMove(_ src: String, _ dest: String) -> [String: Any] {
        do {
            if FileManager.default.fileExists(atPath: dest) {
                try FileManager.default.removeItem(atPath: dest)
            }
            try FileManager.default.moveItem(atPath: src, toPath: dest)
            return ["status_code": 200]
        } catch {
            return ["status_code": 500, "error": error.localizedDescription]
        }
    }
}
