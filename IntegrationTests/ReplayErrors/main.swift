import Foundation
import HTTPTypes
import OpenAPITransportKitCore
import OpenAPITransportKitReplay

enum CheckFailure: Error {
    case expectedInvalidRecord(String)
    case expectedInvalidFingerprintHeaderName
}

let directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent(".build/replay-errors-\(UUID().uuidString)", isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: directory) }

let store = FileReplayStore(rootDirectory: directory)
let key = ReplayKey(operationID: "replay-error-check", requestFingerprint: "fingerprint", scenario: "invalid")

for content in ["not JSON", "{}"] {
    try Data(content.utf8).write(to: store.url(for: key), options: .atomic)
    do {
        _ = try await store.record(for: key)
        throw CheckFailure.expectedInvalidRecord(content)
    } catch ReplayError.invalidRecord(let actualKey, _) where actualKey == key {
    }
}

let fingerprinter = StableRequestFingerprinter(includedHeaderNames: ["not a header"])
let context = TransportRequestContext(
    request: HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/"),
    body: nil,
    baseURL: URL(string: "https://example.com")!,
    operationID: "replay-error-check"
)
do {
    _ = try await fingerprinter.fingerprint(for: context)
    throw CheckFailure.expectedInvalidFingerprintHeaderName
} catch ReplayError.invalidFingerprintHeaderName(let name) where name == "not a header" {
}

print("Replay error checks passed (3 cases).")
