// Copyright Core DF — Apache License 2.0

import Foundation

public enum Httpclient {
    private static func parseBody(_ data: Data) -> Any? {
        guard !data.isEmpty else { return nil }
        if let obj = try? JSONSerialization.jsonObject(with: data) { return obj }
        return String(data: data, encoding: .utf8)
    }

    private static func request(_ method: String, url: String, headers: [String: String] = [:], body: Data? = nil) -> [String: Any] {
        var req = URLRequest(url: URL(string: url)!)
        req.httpMethod = method
        req.timeoutInterval = 60
        headers.forEach { req.setValue($0.value, forHTTPHeaderField: $0.key) }
        req.httpBody = body

        let sem = DispatchSemaphore(value: 0)
        var out: [String: Any] = CoreautoResult.transportError()
        URLSession.shared.dataTask(with: req) { data, resp, err in
            defer { sem.signal() }
            if let err {
                out = CoreautoResult.transportError(err.localizedDescription)
                return
            }
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            let parsed = parseBody(data ?? Data())
            if code >= 400 {
                out = ["status_code": code, "error": parsed ?? "inaccessible"]
            } else {
                out = ["status_code": code, "body": parsed as Any]
            }
        }.resume()
        sem.wait()
        return out
    }

    public static func Get(_ url: String, headers: [String: String]? = nil, params: [String: String]? = nil) -> [String: Any] {
        var u = url
        if let params, !params.isEmpty {
            let qs = params.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
            u += (u.contains("?") ? "&" : "?") + qs
        }
        return request("GET", url: u, headers: headers ?? [:])
    }

    public static func Post(_ url: String, jsonBody: Any? = nil, data: String? = nil, headers: [String: String]? = nil) -> [String: Any] {
        var hdrs = headers ?? [:]
        var bodyData: Data?
        if let jsonBody {
            hdrs["Content-Type"] = hdrs["Content-Type"] ?? "application/json"
            bodyData = try? JSONSerialization.data(withJSONObject: jsonBody)
        } else if let data {
            bodyData = data.data(using: .utf8)
        }
        return request("POST", url: url, headers: hdrs, body: bodyData)
    }

    public static func Put(_ url: String, jsonBody: Any? = nil, headers: [String: String]? = nil) -> [String: Any] {
        var hdrs = headers ?? [:]
        var bodyData: Data?
        if let jsonBody {
            hdrs["Content-Type"] = hdrs["Content-Type"] ?? "application/json"
            bodyData = try? JSONSerialization.data(withJSONObject: jsonBody)
        }
        return request("PUT", url: url, headers: hdrs, body: bodyData)
    }

    public static func Delete(_ url: String, headers: [String: String]? = nil) -> [String: Any] {
        request("DELETE", url: url, headers: headers ?? [:])
    }
}
