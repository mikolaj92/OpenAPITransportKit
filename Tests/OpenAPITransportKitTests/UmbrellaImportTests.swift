import OpenAPITransportKit
import XCTest

final class UmbrellaImportTests: XCTestCase {
    func testUmbrellaModuleReexportsPublicModules() async throws {
        let provider = ClosureResponseProvider { _ in
            TransportResponse(status: .ok)
        }
        let transport = ProviderTransport(provider: provider)

        let (response, _) = try await transport.send(
            HTTPRequest(method: .get, scheme: "https", authority: "example.com", path: "/"),
            body: nil,
            baseURL: URL(string: "https://example.com")!,
            operationID: "health"
        )

        XCTAssertEqual(response.status, .ok)
    }
}

