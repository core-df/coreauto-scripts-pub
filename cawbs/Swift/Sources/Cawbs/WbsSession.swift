// Copyright Core DF

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
// Shared HTTP helpers for the Core Auto Collector (cawbs) Swift client.

import Foundation

public struct Result: Codable {
    public var statusCode: Int
    public var error: AnyCodable?
    public var payload: AnyCodable?
    public var answer: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case statusCode = "status_code"
        case error, payload, answer
    }

    public init(statusCode: Int, error: AnyCodable? = nil, payload: AnyCodable? = nil, answer: [String: AnyCodable]? = nil) {
        self.statusCode = statusCode
        self.error = error
        self.payload = payload
        self.answer = answer
    }
}

public struct AnyCodable: Codable {
    public let value: Any

    public init(_ value: Any) { self.value = value }

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { value = NSNull(); return }
        if let b = try? c.decode(Bool.self) { value = b; return }
        if let i = try? c.decode(Int.self) { value = i; return }
        if let d = try? c.decode(Double.self) { value = d; return }
        if let s = try? c.decode(String.self) { value = s; return }
        if let arr = try? c.decode([AnyCodable].self) { value = arr.map(\.value); return }
        if let dict = try? c.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }; return
        }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported JSON")
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case is NSNull: try c.encodeNil()
        case let b as Bool: try c.encode(b)
        case let i as Int: try c.encode(i)
        case let d as Double: try c.encode(d)
        case let s as String: try c.encode(s)
        default: try c.encode(String(describing: value))
        }
    }
}

public final class WbsSession {
    private var initialized = false
    private var baseURL = ""
    private var env = ""
    private var token = ""

    public init() {}

    public static func missingEnv(_ vars: String) -> Result {
        Result(statusCode: 601, error: AnyCodable("Environment variables \(vars) should be defined"))
    }

    private func trimURL(_ url: String) -> String {
        url.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
    }

    private func request(method: String, url: String, body: Data? = nil) throws -> (Int, Data) {
        var req = URLRequest(url: URL(string: url)!)
        req.httpMethod = method
        req.timeoutInterval = 60
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(env, forHTTPHeaderField: "Environment")
        if !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = body

        let sem = DispatchSemaphore(value: 0)
        var outCode = 0
        var outData = Data()
        var outError: Error?
        URLSession.shared.dataTask(with: req) { data, resp, err in
            defer { sem.signal() }
            if let err { outError = err; return }
            outCode = (resp as? HTTPURLResponse)?.statusCode ?? 0
            outData = data ?? Data()
        }.resume()
        sem.wait()
        if outError != nil { throw outError! }
        return (outCode, outData)
    }

    private func apiError(_ statusCode: Int, _ data: Data) -> Result {
        if let obj = try? JSONSerialization.jsonObject(with: data) {
            return Result(statusCode: statusCode, error: AnyCodable(obj))
        }
        return Result(statusCode: statusCode, error: AnyCodable("inaccessible"))
    }

    public func authenticate(env: String, accessCode: String, baseURL: String) -> Result {
        if initialized {
            return Result(statusCode: 602, error: AnyCodable("init already called"))
        }
        self.env = env
        self.baseURL = trimURL(baseURL)
        let todo = try? JSONSerialization.data(withJSONObject: ["apiCode": accessCode])
        guard let todo else { return Result(statusCode: 500, error: AnyCodable("inaccessible")) }
        do {
            let (code, data) = try request(method: "POST", url: self.baseURL + "/v1/auth/apicode", body: todo)
            if code >= 400 { return apiError(code, data) }
            guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let t = obj["token"] as? String else {
                return Result(statusCode: code, error: AnyCodable("inaccessible"))
            }
            token = t
            initialized = true
            return Result(statusCode: code)
        } catch {
            return Result(statusCode: 0, error: AnyCodable("inaccessible"))
        }
    }

    public func getEventPayload(actionID: String) -> Result {
        if !initialized { return Result(statusCode: 603, error: AnyCodable("Init required")) }
        do {
            let (code, data) = try request(method: "GET", url: baseURL + "/v1/rtevent/" + actionID)
            if code >= 400 { return apiError(code, data) }
            guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return Result(statusCode: code, error: AnyCodable("inaccessible"))
            }
            return Result(statusCode: code, payload: AnyCodable(obj["payload"] as Any))
        } catch {
            return Result(statusCode: 0, error: AnyCodable("inaccessible"))
        }
    }

    public func putStepPayload(actionID: String, stepName: String, payload: Any) -> Result {
        if !initialized { return Result(statusCode: 603, error: AnyCodable("Init required")) }
        let todoObj: [String: Any] = ["actionId": actionID, "stepname": stepName, "payload": payload]
        guard let todo = try? JSONSerialization.data(withJSONObject: todoObj) else {
            return Result(statusCode: 500, error: AnyCodable("inaccessible"))
        }
        do {
            let (code, data) = try request(method: "POST", url: baseURL + "/v1/rtstep/payload", body: todo)
            if code >= 400 { return apiError(code, data) }
            return Result(statusCode: code)
        } catch {
            return Result(statusCode: 0, error: AnyCodable("inaccessible"))
        }
    }

    public func getStepPayload(actionID: String, stepName: String) -> Result {
        if !initialized { return Result(statusCode: 603, error: AnyCodable("Init required")) }
        do {
            let url = baseURL + "/v1/rtstep/payload/" + actionID + "/" + stepName
            let (code, data) = try request(method: "GET", url: url)
            if code >= 400 { return apiError(code, data) }
            guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return Result(statusCode: code, error: AnyCodable("inaccessible"))
            }
            return Result(statusCode: code, payload: AnyCodable(obj["payload"] as Any))
        } catch {
            return Result(statusCode: 0, error: AnyCodable("inaccessible"))
        }
    }

    public func getKeystore(keylist: String) -> Result {
        if !initialized { return Result(statusCode: 603, error: AnyCodable("Init required")) }
        let keys = keylist.replacingOccurrences(of: " ", with: "")
        do {
            let (code, data) = try request(method: "GET", url: baseURL + "/v1/keystore/" + keys)
            if code >= 400 { return apiError(code, data) }
            guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return Result(statusCode: code, error: AnyCodable("inaccessible"))
            }
            for key in keys.split(separator: ",") where !key.isEmpty {
                if obj[String(key)] == nil {
                    return Result(statusCode: 605, error: AnyCodable("\(key) not found"))
                }
            }
            var answer: [String: AnyCodable] = [:]
            for (k, v) in obj { answer[k] = AnyCodable(v) }
            return Result(statusCode: code, answer: answer)
        } catch {
            return Result(statusCode: 0, error: AnyCodable("inaccessible"))
        }
    }

    public func postEvent(eventName: String, payload: Any, eventSource: String? = nil) -> Result {
        if !initialized { return Result(statusCode: 603, error: AnyCodable("Init required")) }
        var todoObj: [String: Any] = ["eventName": eventName, "payload": payload]
        if let eventSource { todoObj["eventSource"] = eventSource }
        guard let todo = try? JSONSerialization.data(withJSONObject: todoObj) else {
            return Result(statusCode: 500, error: AnyCodable("inaccessible"))
        }
        do {
            let (code, data) = try request(method: "POST", url: baseURL + "/v1/rtevent", body: todo)
            if code >= 400 { return apiError(code, data) }
            guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return Result(statusCode: code, error: AnyCodable("inaccessible"))
            }
            var resultPayload: [String: Any] = [:]
            if let eventId = obj["eventId"] { resultPayload["eventId"] = eventId }
            if let actionId = obj["actionId"] { resultPayload["actionId"] = actionId }
            if let createdAt = obj["createdAt"] { resultPayload["createdAt"] = createdAt }
            return Result(statusCode: code, payload: AnyCodable(resultPayload))
        } catch {
            return Result(statusCode: 0, error: AnyCodable("inaccessible"))
        }
    }

    public func getEventStatus(actionID: String) -> Result {
        if !initialized { return Result(statusCode: 603, error: AnyCodable("Init required")) }
        do {
            let (code, data) = try request(method: "GET", url: baseURL + "/v1/rtevent/status/" + actionID)
            if code >= 400 { return apiError(code, data) }
            guard let obj = try? JSONSerialization.jsonObject(with: data) else {
                return Result(statusCode: code, error: AnyCodable("inaccessible"))
            }
            return Result(statusCode: code, payload: AnyCodable(obj))
        } catch {
            return Result(statusCode: 0, error: AnyCodable("inaccessible"))
        }
    }

    public func getEventList() -> Result {
        if !initialized { return Result(statusCode: 603, error: AnyCodable("Init required")) }
        do {
            let (code, data) = try request(method: "GET", url: baseURL + "/v1/rtevent/list")
            if code >= 400 { return apiError(code, data) }
            guard let obj = try? JSONSerialization.jsonObject(with: data) else {
                return Result(statusCode: code, error: AnyCodable("inaccessible"))
            }
            return Result(statusCode: code, payload: AnyCodable(obj))
        } catch {
            return Result(statusCode: 0, error: AnyCodable("inaccessible"))
        }
    }

    public func submitFlag(name: String, systemName: String, sourceSystemName: String, date: String) -> Result {
        if !initialized { return Result(statusCode: 603, error: AnyCodable("Init required")) }
        let todoObj: [String: Any] = [
            "name": name,
            "systemName": systemName,
            "sourceSystemName": sourceSystemName,
            "date": date,
        ]
        guard let todo = try? JSONSerialization.data(withJSONObject: todoObj) else {
            return Result(statusCode: 500, error: AnyCodable("inaccessible"))
        }
        do {
            let (code, data) = try request(method: "POST", url: baseURL + "/v1/flag", body: todo)
            if code >= 400 { return apiError(code, data) }
            guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let status = obj["status"] else {
                return Result(statusCode: code, error: AnyCodable("inaccessible"))
            }
            return Result(statusCode: code, payload: AnyCodable(["flagStatus": status]))
        } catch {
            return Result(statusCode: 0, error: AnyCodable("inaccessible"))
        }
    }
}
