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
struct SelectionTests {

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

}
