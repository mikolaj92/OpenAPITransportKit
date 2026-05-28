import Foundation
import OpenAPIRuntime
import OpenAPITransportKit
import XCTest

final class GeneratedClientTransportTests: XCTestCase {
    func testDynamicTransportPreservesGeneratedClientPipeline() async throws {
        let provider = ClosureResponseProvider { context in
            try Self.require(context.operationID == "getGreeting")
            try Self.require(context.request.method == .get)
            try Self.require(context.request.path?.hasPrefix("/greet?") == true)
            try Self.require(context.request.path?.contains("name=Blob") == true)

            return TransportResponse(
                status: .ok,
                headerFields: Self.jsonHeaderFields(),
                body: HTTPBody(#"{"message":"Hello, Blob!"}"#)
            )
        }
        let client = Client(
            serverURL: URL(string: "https://example.com/api")!,
            transport: ProviderTransport(provider: provider)
        )

        let response = try await client.getGreeting(query: Operations.GetGreeting.Input.Query(name: "Blob"))

        XCTAssertEqual(try response.ok.body.json.message, "Hello, Blob!")
    }

    func testFixtureTransportPreservesGeneratedClientDeserialization() async throws {
        let provider = FixtureResponseProvider(
            loader: MemoryFixtureLoader(fixtures: [
                "getDashboard.success.json": FixturePayload(string: #"{"items":["one","two"]}"#)
            ]),
            scenarioProvider: StaticScenarioProvider(.success)
        )
        let client = Client(
            serverURL: URL(string: "https://example.com/api")!,
            transport: ProviderTransport(provider: provider)
        )

        let response = try await client.getDashboard()

        XCTAssertEqual(try response.ok.body.json.items, ["one", "two"])
    }

    func testFixtureTransportPreservesGeneratedStatusHandling() async throws {
        let provider = FixtureResponseProvider(
            loader: MemoryFixtureLoader(fixtures: [
                "getDashboard.error.json": FixturePayload(
                    string: #"{"message":"Bad dashboard"}"#,
                    metadata: FixtureResponseMetadata(status: .badRequest)
                )
            ]),
            scenarioProvider: StaticScenarioProvider(.error)
        )
        let client = Client(
            serverURL: URL(string: "https://example.com/api")!,
            transport: ProviderTransport(provider: provider)
        )

        let response = try await client.getDashboard()

        XCTAssertEqual(try response.badRequest.body.json.message, "Bad dashboard")
    }

    private static func require(_ condition: @autoclosure () -> Bool) throws {
        if !condition() {
            throw GeneratedClientTransportTestError.failedExpectation
        }
    }

    private static func jsonHeaderFields() -> HTTPFields {
        var fields = HTTPFields()
        fields[.contentType] = "application/json"
        return fields
    }
}

private enum GeneratedClientTransportTestError: Error {
    case failedExpectation
}
