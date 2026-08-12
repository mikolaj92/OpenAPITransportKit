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
struct TransportKitTests {

    @Test
    func testProviderTransportPassesOperationContextToProvider() async throws {
        let transport = ProviderTransport(
            provider: ClosureResponseProvider { context in
                #expect(context.operationID == "getDashboard")
                #expect(context.request.path == "/dashboard")
                return TransportResponse(status: .created, body: HTTPBody("created"))
            }
        )

        let (response, body) = try await transport.send(
            dashboardRequest(),
            body: nil,
            baseURL: baseURL(),
            operationID: "getDashboard"
        )

        #expect(response.status == .created)
        let bodyText = try await String(collecting: #require(body), upTo: 1024)
        #expect(bodyText == "created")
    }

    @Test
    func testFixtureProviderLoadsFixtureByOperationIDAndScenario() async throws {
        let loader = MemoryFixtureLoader(fixtures: [
            "getDashboard.empty.json": FixturePayload(string: #"{"items":[]}"#)
        ])
        let transport = FixtureTransport(
            loader: loader,
            scenario: .empty
        )

        let (response, body) = try await transport.send(
            dashboardRequest(),
            body: nil,
            baseURL: baseURL(),
            operationID: "getDashboard"
        )

        #expect(response.status == .ok)
        #expect(response.headerFields[.contentType] == "application/json")
        let bodyText = try await String(collecting: #require(body), upTo: 1024)
        #expect(bodyText == #"{"items":[]}"#)
    }

    @Test
    func testFixtureMetadataOverridesDefaultStatus() async throws {
        let loader = MemoryFixtureLoader(fixtures: [
            "getDashboard.error.json": FixturePayload(
                string: #"{"message":"nope"}"#,
                metadata: FixtureResponseMetadata(status: .badRequest)
            )
        ])
        let provider = FixtureResponseProvider(
            loader: loader,
            scenarioProvider: StaticScenarioProvider(.error)
        )

        let output = try await provider.response(
            for: TransportRequestContext(
                request: dashboardRequest(),
                body: nil,
                baseURL: baseURL(),
                operationID: "getDashboard"
            )
        )

        #expect(output.response.status == .badRequest)
        #expect(output.response.headerFields[.contentType] == "application/json")
    }

    @Test
    func testFixtureMetadataHeadersMergeWithDefaults() async throws {
        var metadataFields = HTTPFields()
        metadataFields[HTTPField.Name("X-Fixture")!] = "partial"
        let loader = MemoryFixtureLoader(fixtures: [
            "getDashboard.success.json": FixturePayload(
                string: #"{"items":[]}"#,
                metadata: FixtureResponseMetadata(headerFields: metadataFields)
            )
        ])
        let provider = FixtureResponseProvider(
            loader: loader,
            scenarioProvider: StaticScenarioProvider(.success)
        )

        let output = try await provider.response(
            for: TransportRequestContext(
                request: dashboardRequest(),
                body: nil,
                baseURL: baseURL(),
                operationID: "getDashboard"
            )
        )

        #expect(output.response.status == .ok)
        #expect(output.response.headerFields[.contentType] == "application/json")
        #expect(output.response.headerFields[HTTPField.Name("X-Fixture")!] == "partial")
    }

    @Test
    func testFixtureMetadataDocumentPreservesRepeatedHeaders() throws {
        let setCookie = HTTPField.Name("Set-Cookie")!
        var fields = HTTPFields()
        fields.append(HTTPField(name: setCookie, value: "a=1"))
        fields.append(HTTPField(name: setCookie, value: "b=2"))

        let document = FixtureResponseMetadataDocument(
            metadata: FixtureResponseMetadata(headerFields: fields)
        )
        let metadata = try document.metadata()
        let roundTripFields = try #require(metadata.headerFields)

        #expect(document.headers == nil)
        #expect(document.headerFields == [
            FixtureHeaderFieldDocument(name: "Set-Cookie", value: "a=1"),
            FixtureHeaderFieldDocument(name: "Set-Cookie", value: "b=2"),
        ])
        #expect(roundTripFields[values: setCookie] == ["a=1", "b=2"])
    }

    @Test
    func testFileSystemFixtureLoaderReadsMetadataSidecar() async throws {
        let directory = temporaryDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(#"{"items":["file"]}"#.utf8).write(
            to: directory.appendingPathComponent("getDashboard.success.json")
        )
        try Data(
            """
            {
              "status": 202,
              "headers": {
                "Content-Type": "application/json",
                "X-Fixture": "file"
              }
            }
            """.utf8
        ).write(to: directory.appendingPathComponent("getDashboard.success.meta.json"))

        let provider = FixtureResponseProvider(
            loader: FileSystemFixtureLoader(rootDirectory: directory),
            scenarioProvider: StaticScenarioProvider(.success)
        )

        let output = try await provider.response(
            for: TransportRequestContext(
                request: dashboardRequest(),
                body: nil,
                baseURL: baseURL(),
                operationID: "getDashboard"
            )
        )

        #expect(output.response.status == .accepted)
        #expect(output.response.headerFields[.contentType] == "application/json")
        #expect(output.response.headerFields[HTTPField.Name("X-Fixture")!] == "file")
        let bodyText = try await String(collecting: #require(output.body), upTo: 1024)
        #expect(bodyText == #"{"items":["file"]}"#)
    }

    @Test
    func testBundleFixtureLoaderReadsResourceAndMetadataSidecar() async throws {
        let provider = FixtureResponseProvider(
            loader: BundleFixtureLoader(
                bundle: .module,
                subdirectory: "Fixtures"
            ),
            scenarioProvider: StaticScenarioProvider("sidecar")
        )

        let output = try await provider.response(
            for: TransportRequestContext(
                request: dashboardRequest(),
                body: nil,
                baseURL: baseURL(),
                operationID: "getDashboard"
            )
        )

        #expect(output.response.status == .accepted)
        #expect(output.response.headerFields[.contentType] == "application/json")
        #expect(output.response.headerFields[HTTPField.Name("X-Fixture")!] == "bundle")
        let bodyText = try await String(collecting: #require(output.body), upTo: 1024)
        #expect(bodyText.trimmingCharacters(in: .whitespacesAndNewlines) == #"{"items":["resource"]}"#)
    }

    @Test
    func testBundleFixtureLoaderDoesNotFallBackToRootWhenSubdirectoryIsMissing() async throws {
        let loader = BundleFixtureLoader(bundle: .module, subdirectory: "Missing")

        do {
            _ = try await loader.load(FixtureReference(rawValue: "getDashboard.sidecar.json"))
            Issue.record("Expected missing fixture error.")
        } catch FixtureError.missingFixture(let reference) {
            #expect(reference.rawValue == "getDashboard.sidecar.json")
        }
    }

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
        let key = ReplayKey(operationID: "getDashboard", requestFingerprint: "abc123", scenario: "success")
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
    func testRecordingMiddlewareWithBodyFingerprintPreservesRequestBodyToNextTransport() async throws {
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
    func testStatefulResponseProviderPersistsUserDefinedState() async throws {
        struct CounterState: Sendable, Equatable {
            var count: Int
        }

        let transport = StatefulTransport<CounterState>(initialState: CounterState(count: 0)) { _, state in
            let nextState = CounterState(count: state.count + 1)
            return StatefulProviderOutput(
                state: nextState,
                response: TransportResponse(status: .ok, body: HTTPBody("\(nextState.count)"))
            )
        }
        let provider = transport.provider

        let (_, firstBody) = try await transport.send(
            dashboardRequest(),
            body: nil,
            baseURL: baseURL(),
            operationID: "getDashboard"
        )
        let (_, secondBody) = try await transport.send(
            dashboardRequest(),
            body: nil,
            baseURL: baseURL(),
            operationID: "getDashboard"
        )

        let firstText = try await String(collecting: #require(firstBody), upTo: 1024)
        let secondText = try await String(collecting: #require(secondBody), upTo: 1024)

        #expect(firstText == "1")
        #expect(secondText == "2")
        let currentState = await provider.currentState()
        #expect(currentState == CounterState(count: 2))
    }

    @Test
    func testStatefulProviderTransportPersistsUserDefinedStateWithCustomHandler() async throws {
        struct CounterState: Sendable, Equatable {
            var count: Int
        }

        let provider = StatefulResponseProvider(
            initialState: CounterState(count: 0),
            handler: ClosureStatefulResponseHandler<CounterState> { _, state in
                let nextState = CounterState(count: state.count + 1)
                return StatefulProviderOutput(
                    state: nextState,
                    response: TransportResponse(status: .ok, body: HTTPBody("\(nextState.count)"))
                )
            }
        )
        let transport = StatefulProviderTransport(provider: provider)

        let (_, firstBody) = try await transport.send(
            dashboardRequest(),
            body: nil,
            baseURL: baseURL(),
            operationID: "getDashboard"
        )
        let (_, secondBody) = try await transport.send(
            dashboardRequest(),
            body: nil,
            baseURL: baseURL(),
            operationID: "getDashboard"
        )

        let firstText = try await String(collecting: #require(firstBody), upTo: 1024)
        let secondText = try await String(collecting: #require(secondBody), upTo: 1024)

        #expect(firstText == "1")
        #expect(secondText == "2")
        let currentState = await provider.currentState()
        #expect(currentState == CounterState(count: 2))
    }

    @Test
    func testStatefulResponseProviderSerializesConcurrentMutations() async throws {
        struct CounterState: Sendable, Equatable {
            var count: Int
        }

        let provider = StatefulResponseProvider(
            initialState: CounterState(count: 0),
            handler: ClosureStatefulResponseHandler<CounterState> { _, state in
                await Task.yield()
                let nextState = CounterState(count: state.count + 1)
                return StatefulProviderOutput(
                    state: nextState,
                    response: TransportResponse(status: .ok, body: HTTPBody("\(nextState.count)"))
                )
            }
        )

        let values = try await withThrowingTaskGroup(of: Int.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    let output = try await provider.response(
                        for: TransportRequestContext(
                            request: dashboardRequest(),
                            body: nil,
                            baseURL: baseURL(),
                            operationID: "getDashboard"
                        )
                    )
                    let body = try #require(output.body)
                    let text = try await String(collecting: body, upTo: 1024)
                    return try #require(Int(text))
                }
            }

            var values = [Int]()
            for try await value in group {
                values.append(value)
            }
            return values
        }
        let currentState = await provider.currentState()

        #expect(currentState == CounterState(count: 20))
        #expect(values.sorted() == Array(1...20))
    }

    @Test
    func testStatefulResponseProviderDoesNotCommitCancelledMutation() async throws {
        struct CounterState: Sendable, Equatable {
            var count: Int
        }

        let provider = StatefulResponseProvider(
            initialState: CounterState(count: 0),
            handler: ClosureStatefulResponseHandler<CounterState> { _, state in
                try await Task.sleep(nanoseconds: 100_000_000)
                let nextState = CounterState(count: state.count + 1)
                return StatefulProviderOutput(
                    state: nextState,
                    response: TransportResponse(status: .ok)
                )
            }
        )
        let task = Task {
            try await provider.response(
                for: TransportRequestContext(
                    request: dashboardRequest(),
                    body: nil,
                    baseURL: baseURL(),
                    operationID: "getDashboard"
                )
            )
        }

        await Task.yield()
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected cancellation.")
        } catch is CancellationError {
        }
        let currentState = await provider.currentState()

        #expect(currentState == CounterState(count: 0))
    }

    @Test
    func testMultiplexingTransportSourcesByTypedSource() async throws {
        let fixtureTransport = DynamicTransport { _ in
            TransportResponse(status: .ok, body: HTTPBody("fixture"))
        }
        let liveTransport = StaticClientTransport(status: .created, body: "live")
        let selector = SourceSwitchingTransportSelector(
            sourceProvider: ClosureTransportSourceProvider { _ in .fixtures },
            registry: TransportSourceRegistry(
                live: liveTransport,
                fixtures: fixtureTransport
            )
        )
        let transport = MultiplexingTransport(selector: selector)

        let (response, body) = try await transport.send(
            dashboardRequest(),
            body: nil,
            baseURL: baseURL(),
            operationID: "getDashboard"
        )

        #expect(response.status == .ok)
        let bodyText = try await String(collecting: #require(body), upTo: 1024)
        #expect(bodyText == "fixture")
    }

    @Test
    func testSourceSwitchingTransportSelectorThrowsWhenSourceIsMissing() async throws {
        let selector = SourceSwitchingTransportSelector(
            sourceProvider: StaticTransportSourceProvider(.fixtures),
            registry: TransportSourceRegistry()
        )

        do {
            _ = try await selector.transport(
                for: TransportRequestContext(
                    request: dashboardRequest(),
                    body: nil,
                    baseURL: baseURL(),
                    operationID: "getDashboard"
                )
            )
            Issue.record("Expected missing transport error.")
        } catch TransportSelectionError.missingTransport(let source) {
            #expect(source == .fixtures)
        }
    }

    @Test
    func testSourceSwitchingTransportSelectorDoesNotFallBackWhenSourceIsMissing() async throws {
        let liveTransport = StaticClientTransport(status: .created, body: "live")
        let selector = SourceSwitchingTransportSelector(
            sourceProvider: StaticTransportSourceProvider(.fixtures),
            registry: TransportSourceRegistry(live: liveTransport)
        )

        do {
            _ = try await selector.transport(
                for: TransportRequestContext(
                    request: dashboardRequest(),
                    body: nil,
                    baseURL: baseURL(),
                    operationID: "getDashboard"
                )
            )
            Issue.record("Expected missing transport error.")
        } catch TransportSelectionError.missingTransport(let source) {
            #expect(source == .fixtures)
        }
    }

    @Test
    func testMissingFixtureThrowsConfigurationError() async throws {
        let provider = FixtureResponseProvider(
            loader: MemoryFixtureLoader(fixtures: [:]),
            scenarioProvider: StaticScenarioProvider(.success)
        )

        do {
            _ = try await provider.response(
                for: TransportRequestContext(
                    request: dashboardRequest(),
                    body: nil,
                    baseURL: baseURL(),
                    operationID: "getDashboard"
                )
            )
            Issue.record("Expected missing fixture error.")
        } catch FixtureError.missingFixture(let reference) {
            #expect(reference.rawValue == "getDashboard.success.json")
        }
    }
}

private struct StaticClientTransport: ClientTransport {
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

private func dashboardRequest() -> HTTPRequest {
    HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/dashboard")
}

private func baseURL() -> URL {
    URL(string: "https://example.com")!
}

private func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
}
