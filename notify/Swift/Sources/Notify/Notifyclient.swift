// Copyright Core DF — Apache License 2.0

import Foundation

public enum Notifyclient {
    private static func env(_ key: String) -> String {
        ProcessInfo.processInfo.environment[key] ?? ""
    }

    private static func postJson(_ url: String, payload: [String: Any]) -> [String: Any] {
        guard let target = URL(string: url) else {
            return CoreautoResult.transportError("invalid url")
        }
        var req = URLRequest(url: target)
        req.httpMethod = "POST"
        req.timeoutInterval = 30
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
            return CoreautoResult.transportError("json encode failed")
        }
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
            let text = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            if code >= 400 {
                out = ["status_code": code, "error": text]
                return
            }
            if text.isEmpty {
                out = ["status_code": 200]
                return
            }
            if let parsed = try? JSONSerialization.jsonObject(with: Data(text.utf8)) {
                out = ["status_code": 200, "body": parsed]
            } else {
                out = ["status_code": 200, "body": text]
            }
        }.resume()
        sem.wait()
        return out
    }

    public static func Slack(_ text: String, webhookUrl: String? = nil) -> [String: Any] {
        let url = (webhookUrl?.isEmpty == false ? webhookUrl : nil) ?? env("SLACK_WEBHOOK_URL")
        if url.isEmpty { return CoreautoResult.missingEnv("SLACK_WEBHOOK_URL") }
        return postJson(url, payload: ["text": text])
    }

    public static func Teams(_ text: String, webhookUrl: String? = nil) -> [String: Any] {
        let url = (webhookUrl?.isEmpty == false ? webhookUrl : nil) ?? env("TEAMS_WEBHOOK_URL")
        if url.isEmpty { return CoreautoResult.missingEnv("TEAMS_WEBHOOK_URL") }
        return postJson(url, payload: [
            "@type": "MessageCard",
            "@context": "http://schema.org/extensions",
            "text": text,
        ])
    }

    public static func PagerDuty(
        _ summary: String,
        routingKey: String? = nil,
        severity: String = "error"
    ) -> [String: Any] {
        let key = (routingKey?.isEmpty == false ? routingKey : nil) ?? env("PAGERDUTY_ROUTING_KEY")
        if key.isEmpty { return CoreautoResult.missingEnv("PAGERDUTY_ROUTING_KEY") }
        return postJson("https://events.pagerduty.com/v2/enqueue", payload: [
            "routing_key": key,
            "event_action": "trigger",
            "payload": [
                "summary": summary,
                "severity": severity,
                "source": "coreauto-step",
            ],
        ])
    }

    public static func Email(
        _ subject: String,
        _ body: String,
        _ toAddrs: String,
        fromAddr: String? = nil
    ) -> [String: Any] {
        let host = env("SMTP_HOST")
        let port = Int(env("SMTP_PORT")) ?? 587
        let user = env("SMTP_USER")
        let password = env("SMTP_PASSWORD")
        let sender = (fromAddr?.isEmpty == false ? fromAddr : nil) ?? env("SMTP_FROM")
        if host.isEmpty || sender.isEmpty {
            return CoreautoResult.missingEnv("SMTP_HOST and SMTP_FROM (or from_addr)")
        }

        var readBuffer = [UInt8](repeating: 0, count: 512)
        func readOk(_ input: InputStream) -> Bool {
            let n = input.read(&readBuffer, maxLength: readBuffer.count)
            guard n > 0 else { return false }
            return readBuffer[0] == UInt8(ascii: "2") || readBuffer[0] == UInt8(ascii: "3")
        }
        func sendLine(_ output: OutputStream, _ line: String) -> Bool {
            let data = (line + "\r\n").data(using: .utf8)!
            return data.withUnsafeBytes { ptr in
                output.write(ptr.bindMemory(to: UInt8.self).baseAddress!, maxLength: data.count) == data.count
            }
        }

        var inStream: InputStream?
        var outStream: OutputStream?
        Stream.getStreamsToHost(withName: host, port: port, inputStream: &inStream, outputStream: &outStream)
        guard let input = inStream, let output = outStream else {
            return CoreautoResult.transportError("smtp connect failed")
        }
        input.open()
        output.open()
        defer { input.close(); output.close() }

        _ = input.read(&readBuffer, maxLength: readBuffer.count)
        guard sendLine(output, "EHLO coreauto.local"), readOk(input) else {
            return CoreautoResult.transportError("smtp handshake failed")
        }
        if !user.isEmpty && !password.isEmpty {
            _ = sendLine(output, "STARTTLS")
            _ = readOk(input)
        }
        guard sendLine(output, "MAIL FROM:<\(sender)>"), readOk(input),
              sendLine(output, "RCPT TO:<\(toAddrs)>"), readOk(input),
              sendLine(output, "DATA"), readOk(input) else {
            return CoreautoResult.transportError("smtp command failed")
        }
        let msg = "From: \(sender)\r\nTo: \(toAddrs)\r\nSubject: \(subject)\r\n\r\n\(body)\r\n."
        guard let msgData = msg.data(using: .utf8) else {
            return CoreautoResult.transportError("smtp encode failed")
        }
        msgData.withUnsafeBytes { ptr in
            output.write(ptr.bindMemory(to: UInt8.self).baseAddress!, maxLength: msgData.count)
        }
        guard readOk(input) else { return CoreautoResult.transportError("smtp send failed") }
        _ = sendLine(output, "QUIT")
        return ["status_code": 200]
    }
}
