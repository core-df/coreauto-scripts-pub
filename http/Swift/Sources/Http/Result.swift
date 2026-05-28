// Copyright Core DF — Apache License 2.0

import Foundation

public enum CoreautoResult {
    public static func missingEnv(_ vars: String) -> [String: Any] {
        ["status_code": 601, "error": "Environment variables \(vars) should be defined"]
    }

    public static func transportError(_ message: String = "inaccessible") -> [String: Any] {
        ["status_code": 0, "error": message]
    }
}
