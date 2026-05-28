// Copyright Core DF — Apache License 2.0

import Foundation
import NIOCore
import SotoCore
import SotoS3

public enum S3client {
    private static func env(_ key: String, default fallback: String = "") -> String {
        let value = ProcessInfo.processInfo.environment[key] ?? ""
        return value.isEmpty ? fallback : value
    }

    private static func bucket(_ explicit: String?) -> String {
        if let explicit, !explicit.isEmpty { return explicit }
        return env("S3_BUCKET")
    }

    private static func region() -> Region {
        Region(rawValue: env("AWS_REGION", default: env("AWS_DEFAULT_REGION", default: "us-east-1")))
    }

    private static func endpoint() -> String? {
        let url = env("S3_ENDPOINT_URL")
        return url.isEmpty ? nil : url
    }

    private static func block(_ work: @escaping () async throws -> [String: Any]) -> [String: Any] {
        let sem = DispatchSemaphore(value: 0)
        var out: [String: Any] = CoreautoResult.transportError()
        Task {
            do {
                out = try await work()
            } catch {
                out = CoreautoResult.transportError(error.localizedDescription)
            }
            sem.signal()
        }
        sem.wait()
        return out
    }

    private static func withClient(_ work: (S3, AWSClient) async throws -> [String: Any]) -> [String: Any] {
        block {
            let client = AWSClient(credentialProvider: .environment, httpClientProvider: .createNew)
            defer {
                let shutdownSem = DispatchSemaphore(value: 0)
                Task {
                    try? await client.shutdown()
                    shutdownSem.signal()
                }
                shutdownSem.wait()
            }
            let s3 = S3(client: client, region: region(), endpoint: endpoint())
            return try await work(s3, client)
        }
    }

    public static func Init() -> [String: Any] {
        if env("AWS_ACCESS_KEY_ID").isEmpty && env("AWS_PROFILE").isEmpty {
            return CoreautoResult.missingEnv("AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY or AWS_PROFILE")
        }
        if env("S3_BUCKET").isEmpty {
            return CoreautoResult.missingEnv("S3_BUCKET (or pass bucket per call)")
        }
        return ["status_code": 200]
    }

    public static func GetObject(_ key: String, bucketName: String? = nil) -> [String: Any] {
        let b = bucket(bucketName)
        if b.isEmpty { return CoreautoResult.missingEnv("S3_BUCKET") }
        return withClient { s3, _ in
            let resp = try await s3.getObject(.init(bucket: b, key: key))
            guard let body = resp.body else {
                return ["status_code": 200, "content": ""]
            }
            var buffer = try await body.collect(upTo: 64 * 1024 * 1024)
            let content = buffer.readString(length: buffer.readableBytes) ?? ""
            return ["status_code": 200, "content": content]
        }
    }

    public static func PutObject(_ key: String, content: String, bucketName: String? = nil) -> [String: Any] {
        let b = bucket(bucketName)
        if b.isEmpty { return CoreautoResult.missingEnv("S3_BUCKET") }
        return withClient { s3, _ in
            var buffer = ByteBuffer(string: content)
            try await s3.putObject(.init(bucket: b, key: key, body: .buffer(buffer)))
            return ["status_code": 200]
        }
    }

    public static func ListObjects(prefix: String = "", bucketName: String? = nil) -> [String: Any] {
        let b = bucket(bucketName)
        if b.isEmpty { return CoreautoResult.missingEnv("S3_BUCKET") }
        return withClient { s3, _ in
            let resp = try await s3.listObjectsV2(.init(bucket: b, prefix: prefix))
            let keys = resp.contents?.compactMap(\.key) ?? []
            return ["status_code": 200, "keys": keys]
        }
    }
}
