// Copyright Core DF — Apache License 2.0
import Cawbs
import Foundation

let initResult = Cawbs.initSession()
guard initResult.statusCode == 200 else { fatalError("\(initResult.error ?? "init failed")") }

let event = Cawbs.getEventPayload()
guard event.statusCode == 200 else { fatalError("\(event.error ?? "get event failed")") }

var orderId = "unknown"
if let payload = event.payload as? [String: Any] {
    orderId = (payload["orderId"] as? String) ?? (payload["id"] as? String) ?? orderId
}

let ackDir = ProcessInfo.processInfo.environment["EXAMPLE_ACK_DIR"] ?? "/tmp/coreauto-example"
let ackPath = "\(ackDir)/\(orderId).json"
let out: [String: Any] = ["orderId": orderId, "ackPath": ackPath]
let put = Cawbs.putStepPayload(out)
guard put.statusCode == 200 else { fatalError("\(put.error ?? "put step failed")") }

if let data = try? JSONSerialization.data(withJSONObject: ["status_code": 200, "result": out], options: [.prettyPrinted]),
   let json = String(data: data, encoding: .utf8) {
    print(json)
}
