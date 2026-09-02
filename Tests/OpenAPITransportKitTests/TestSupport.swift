import Foundation
import HTTPTypes
import OpenAPIRuntime
import OpenAPITransportKitReplay
import Testing

struct StaticClientTransport: ClientTransport {
  var status: HTTPResponse.Status
  var body: String?

  func send(
    _ request: HTTPRequest,
    body: HTTPBody?,
    baseURL: URL,
    operationID: String
  ) async throws -> (HTTPResponse, HTTPBody?) {
    (HTTPResponse(status: status), self.body.map { HTTPBody($0) })
  }
}

func dashboardRequest() -> HTTPRequest {
  HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/dashboard")
}

func baseURL() -> URL {
  URL(string: "https://example.com")!
}

func temporaryDirectory() -> URL {
  FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString, isDirectory: true)
}

struct FailingReplayWriter: ReplayStoreWriter {
  let key: ReplayKey

  func write(_ record: ReplayRecord, for key: ReplayKey) async throws {
    #expect(key == self.key)
    throw ReplayError.cannotWriteRecord(key, "test writer failure")
  }
}
