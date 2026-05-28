import Foundation
import OpenAPITransportKit
import Testing

@Suite
struct UmbrellaImportTests {

    @Test
    func testUmbrellaModuleReexportsPublicModules() async throws {
        let transport = DynamicTransport { _ in
            TransportResponse(status: .ok)
        }

        let (response, _) = try await transport.send(
            HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/"),
            body: nil,
            baseURL: URL(string: "https://example.com")!,
            operationID: "health"
        )

        #expect(response.status == .ok)
    }
}
