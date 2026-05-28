import Foundation
import OpenAPIRuntime
import OpenAPITransportKit
import Testing

@Suite
struct GeneratedClientTransportTests {

    @Test
    func testDynamicTransportPreservesGeneratedClientPipeline() async throws {
        let transport = DynamicTransport { context in
            #expect(context.operationID == "getGreeting")
            #expect(context.request.method == .get)
            #expect(context.request.path?.hasPrefix("/greet?") == true)
            #expect(context.request.path?.contains("name=Blob") == true)

            return TransportResponse(
                status: .ok,
                headerFields: Self.jsonHeaderFields(),
                body: HTTPBody(#"{"message":"Hello, Blob!"}"#)
            )
        }
        let client = Client(
            serverURL: URL(string: "https://example.com/api")!,
            transport: transport
        )

        let response = try await client.getGreeting(query: Operations.GetGreeting.Input.Query(name: "Blob"))

        #expect(try response.ok.body.json.message == "Hello, Blob!")
    }

    @Test
    func testFixtureTransportPreservesGeneratedClientDeserialization() async throws {
        let transport = FixtureTransport(
            loader: MemoryFixtureLoader(fixtures: [
                "getDashboard.success.json": FixturePayload(string: #"{"items":["one","two"]}"#)
            ])
        )
        let client = Client(
            serverURL: URL(string: "https://example.com/api")!,
            transport: transport
        )

        let response = try await client.getDashboard()

        #expect(try response.ok.body.json.items == ["one", "two"])
    }

    @Test
    func testFixtureTransportPreservesGeneratedStatusHandling() async throws {
        let transport = FixtureTransport(
            loader: MemoryFixtureLoader(fixtures: [
                "getDashboard.error.json": FixturePayload(
                    string: #"{"message":"Bad dashboard"}"#,
                    metadata: FixtureResponseMetadata(status: .badRequest)
                )
            ]),
            scenario: .error
        )
        let client = Client(
            serverURL: URL(string: "https://example.com/api")!,
            transport: transport
        )

        let response = try await client.getDashboard()

        #expect(try response.badRequest.body.json.message == "Bad dashboard")
    }

    private static func jsonHeaderFields() -> HTTPFields {
        var fields = HTTPFields()
        fields[.contentType] = "application/json"
        return fields
    }
}
