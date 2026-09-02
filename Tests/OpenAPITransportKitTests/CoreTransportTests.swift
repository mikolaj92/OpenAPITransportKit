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
struct CoreTransportTests {

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

}
