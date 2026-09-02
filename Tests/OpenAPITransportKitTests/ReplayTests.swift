import Foundation
import HTTPTypes
import OpenAPIRuntime
import OpenAPITransportKitCore
import OpenAPITransportKitDynamic
import OpenAPITransportKitFixtures
import OpenAPITransportKitReplay
import OpenAPITransportKitStateful
import Testing

@Suite
struct ReplayTests {

  @Test
  func testReplayProviderReturnsRecordedResponse() async throws {
    let key = ReplayKey(operationID: "getDashboard")
    let store = MemoryReplayStore(records: [
      key: ReplayRecord(response: HTTPResponse(status: .accepted), body: Data("replayed".utf8))
    ])
    let transport = ReplayTransport(store: store)

    let (response, body) = try await transport.send(
      dashboardRequest(),
      body: nil,
      baseURL: baseURL(),
      operationID: "getDashboard"
    )

    #expect(response.status == .accepted)
    let bodyText = try await String(collecting: #require(body), upTo: 1024)
    #expect(bodyText == "replayed")
  }

  @Test
  func testFileReplayStoreWritesAndReadsRecordedResponse() async throws {
    let directory = temporaryDirectory()
    let store = FileReplayStore(rootDirectory: directory)
    let key = ReplayKey(
      operationID: "getDashboard", requestFingerprint: "abc123", scenario: "success")
    let record = ReplayRecord(
      response: HTTPResponse(status: .created),
      body: Data("stored".utf8),
      recordedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )

    try await store.write(record, for: key)
    let optionalLoaded = try await store.record(for: key)
    let loaded = try #require(optionalLoaded)

    #expect(loaded.response.status == .created)
    #expect(loaded.body == Data("stored".utf8))
    #expect(loaded.recordedAt == Date(timeIntervalSince1970: 1_700_000_000))
  }

  @Test
  func testSafeReplayFileNameStrategyAvoidsLossyComponentCollisions() {
    let strategy = SafeReplayFileNameStrategy()

    let slashName = strategy.fileName(for: ReplayKey(operationID: "a/b"))
    let underscoreName = strategy.fileName(for: ReplayKey(operationID: "a_b"))
    let dottedOperationName = strategy.fileName(for: ReplayKey(operationID: "a.b", scenario: "c"))
    let dottedScenarioName = strategy.fileName(for: ReplayKey(operationID: "a", scenario: "b.c"))

    #expect(slashName != underscoreName)
    #expect(dottedOperationName != dottedScenarioName)
    #expect(!(slashName.contains("/")))
  }

  @Test
  func testFingerprintedReplayKeyStrategyUsesRequestShape() async throws {
    var request = dashboardRequest()
    request.headerFields[HTTPField.Name("X-Scenario")!] = "one"
    let context = TransportRequestContext(
      request: request,
      body: nil,
      baseURL: baseURL(),
      operationID: "getDashboard"
    )
    let strategy = FingerprintedReplayKeyStrategy(
      fingerprinter: StableRequestFingerprinter(includedHeaderNames: ["X-Scenario"]),
      scenario: "success"
    )

    let key = try await strategy.key(for: context)

    #expect(key.operationID == "getDashboard")
    #expect(key.scenario == "success")
    #expect(key.requestFingerprint != nil)

    request.headerFields[HTTPField.Name("X-Scenario")!] = "two"
    let changedContext = TransportRequestContext(
      request: request,
      body: nil,
      baseURL: baseURL(),
      operationID: "getDashboard"
    )
    let changedKey = try await strategy.key(for: changedContext)

    #expect(key.requestFingerprint != changedKey.requestFingerprint)
  }

  @Test
  func testReplayProviderCanUseFingerprintedFileReplayStore() async throws {
    var request = dashboardRequest()
    request.headerFields[HTTPField.Name("X-Scenario")!] = "recorded"
    let context = TransportRequestContext(
      request: request,
      body: nil,
      baseURL: baseURL(),
      operationID: "getDashboard"
    )
    let strategy = FingerprintedReplayKeyStrategy(
      fingerprinter: StableRequestFingerprinter(includedHeaderNames: ["X-Scenario"])
    )
    let key = try await strategy.key(for: context)
    let store = FileReplayStore(rootDirectory: temporaryDirectory())
    try await store.write(
      ReplayRecord(response: HTTPResponse(status: .accepted), body: Data("fingerprinted".utf8)),
      for: key
    )
    let provider = ReplayResponseProvider(store: store, keyStrategy: strategy)

    let output = try await provider.response(for: context)

    #expect(output.response.status == .accepted)
    let bodyText = try await String(collecting: #require(output.body), upTo: 1024)
    #expect(bodyText == "fingerprinted")
  }

  @Test
  func testRecordingMiddlewareWritesReplayRecordAndPreservesResponseBody() async throws {
    let store = FileReplayStore(rootDirectory: temporaryDirectory())
    let middleware = RecordingClientMiddleware(
      writer: store,
      recordedAt: { Date(timeIntervalSince1970: 1_700_000_001) }
    )

    let (response, responseBody) = try await middleware.intercept(
      dashboardRequest(),
      body: nil,
      baseURL: baseURL(),
      operationID: "getDashboard",
      next: { _, _, _ in
        (HTTPResponse(status: .ok), HTTPBody("live-response"))
      }
    )

    #expect(response.status == .ok)
    let responseText = try await String(collecting: #require(responseBody), upTo: 1024)
    #expect(responseText == "live-response")

    let optionalRecord = try await store.record(for: ReplayKey(operationID: "getDashboard"))
    let record = try #require(optionalRecord)
    #expect(record.response.status == .ok)
    #expect(record.body == Data("live-response".utf8))
    #expect(record.recordedAt == Date(timeIntervalSince1970: 1_700_000_001))
  }

  @Test
  func testRecordingMiddlewareReplaysBufferedRequestBodyToNextTransport() async throws {
    let store = FileReplayStore(rootDirectory: temporaryDirectory())
    let middleware = RecordingClientMiddleware(writer: store)

    let (_, responseBody) = try await middleware.intercept(
      dashboardRequest(),
      body: HTTPBody("request-body"),
      baseURL: baseURL(),
      operationID: "postDashboard",
      next: { _, body, _ in
        let requestText = try await String(collecting: #require(body), upTo: 1024)
        return (HTTPResponse(status: .accepted), HTTPBody("echo:\(requestText)"))
      }
    )

    let responseText = try await String(collecting: #require(responseBody), upTo: 1024)
    #expect(responseText == "echo:request-body")
  }

  @Test
  func testRecordingMiddlewareWithBodyFingerprintPreservesRequestBodyToNextTransport() async throws
  {
    let store = FileReplayStore(rootDirectory: temporaryDirectory())
    let keyStrategy = FingerprintedReplayKeyStrategy(
      fingerprinter: StableRequestFingerprinter(includesBody: true)
    )
    let middleware = RecordingClientMiddleware(
      writer: store,
      keyStrategy: keyStrategy
    )

    let (_, responseBody) = try await middleware.intercept(
      dashboardRequest(),
      body: HTTPBody("request-body"),
      baseURL: baseURL(),
      operationID: "postDashboard",
      next: { _, body, _ in
        let requestText = try await String(collecting: #require(body), upTo: 1024)
        return (HTTPResponse(status: .accepted), HTTPBody("echo:\(requestText)"))
      }
    )

    let responseText = try await String(collecting: #require(responseBody), upTo: 1024)
    let key = try await keyStrategy.key(
      for: TransportRequestContext(
        request: dashboardRequest(),
        body: HTTPBody("request-body"),
        baseURL: baseURL(),
        operationID: "postDashboard"
      )
    )
    let optionalRecord = try await store.record(for: key)
    let record = try #require(optionalRecord)

    #expect(responseText == "echo:request-body")
    #expect(record.response.status == .accepted)
    #expect(record.body == Data("echo:request-body".utf8))
  }

  @Test
  func testReplayProviderThrowsWhenRecordIsMissing() async throws {
    let expectedKey = ReplayKey(operationID: "getDashboard")
    let provider = ReplayResponseProvider(store: MemoryReplayStore(records: [:]))

    do {
      _ = try await provider.response(
        for: TransportRequestContext(
          request: dashboardRequest(),
          body: nil,
          baseURL: baseURL(),
          operationID: expectedKey.operationID
        )
      )
      Issue.record("Expected missing replay record error.")
    } catch ReplayError.missingRecord(let key) {
      #expect(key == expectedKey)
    }
  }

  @Test
  func testRecordingFailureStrategyThrowPropagatesWriterFailure() async throws {
    let expectedKey = ReplayKey(operationID: "getDashboard")
    let middleware = RecordingClientMiddleware(
      writer: FailingReplayWriter(key: expectedKey),
      failureStrategy: .throw
    )

    do {
      _ = try await middleware.intercept(
        dashboardRequest(),
        body: nil,
        baseURL: baseURL(),
        operationID: expectedKey.operationID,
        next: { _, _, _ in
          (HTTPResponse(status: .accepted), HTTPBody("live-response"))
        }
      )
      Issue.record("Expected writer failure.")
    } catch ReplayError.cannotWriteRecord(let key, let detail) {
      #expect(key == expectedKey)
      #expect(detail == "test writer failure")
    }
  }

  @Test
  func testRecordingFailureStrategyIgnoreReturnsBufferedLiveResponse() async throws {
    let expectedKey = ReplayKey(operationID: "getDashboard")
    let middleware = RecordingClientMiddleware(
      writer: FailingReplayWriter(key: expectedKey),
      failureStrategy: .ignore
    )

    let (response, body) = try await middleware.intercept(
      dashboardRequest(),
      body: nil,
      baseURL: baseURL(),
      operationID: expectedKey.operationID,
      next: { _, _, _ in
        (HTTPResponse(status: .accepted), HTTPBody("live-response"))
      }
    )

    #expect(response.status == .accepted)
    let bodyText = try await String(collecting: #require(body), upTo: 1024)
    #expect(bodyText == "live-response")
  }

}
