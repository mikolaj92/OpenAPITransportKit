import Foundation
import HTTPTypes
import OpenAPITransportKitCore
import OpenAPITransportKitFixtures
import OpenAPITransportKitReplay

enum CheckFailure: Error {
    case expectedInvalidRecord(String)
    case expectedInvalidFingerprintHeaderName
    case unexpectedFixtureHeaders
    case expectedInvalidFixtureHeaderName
}

func checkReplayErrors() async throws {
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
}

func checkFixtureSidecar() async throws {
    let directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent(".build/fixture-sidecar-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let reference = FixtureReference(rawValue: "response.json")
    let sidecar = directory.appendingPathComponent("response.meta.json")
    try Data(#"{"message":"hello"}"#.utf8)
        .write(to: directory.appendingPathComponent(reference.rawValue), options: .atomic)
    try Data(#"{"headers":{"Content-Type":"application/json"},"headerFields":[{"name":"Set-Cookie","value":"a=1"},{"name":"Set-Cookie","value":"b=2"}]}"#.utf8)
        .write(to: sidecar, options: .atomic)

    let loader = FileSystemFixtureLoader(rootDirectory: directory)
    let payload = try await loader.load(reference)
    guard let headers = payload.metadata?.headerFields,
        headers[.contentType] == "application/json",
        headers.filter({ $0.name == .setCookie }).map(\.value) == ["a=1", "b=2"]
    else {
        throw CheckFailure.unexpectedFixtureHeaders
    }

    try Data(#"{"headerFields":[{"name":"Bad Header","value":"invalid"}]}"#.utf8)
        .write(to: sidecar, options: .atomic)
    do {
        _ = try await loader.load(reference)
        throw CheckFailure.expectedInvalidFixtureHeaderName
    } catch FixtureError.invalidHeaderName(let name) where name == "Bad Header" {
    }
}

try await checkReplayErrors()
try await checkFixtureSidecar()
print("Replay and fixture checks passed (5 cases).")
