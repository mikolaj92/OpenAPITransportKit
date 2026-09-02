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
struct FixtureTests {

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
    #expect(
      document.headerFields == [
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

  @Test
  func testFileSystemFixtureLoaderRejectsInvalidMetadataSidecar() async throws {
    let directory = temporaryDirectory()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let payloadReference = FixtureReference(rawValue: "getDashboard.success.json")
    let metadataReference = FixtureReference(rawValue: "getDashboard.success.meta.json")
    try Data(#"{"items":[]}"#.utf8).write(
      to: directory.appendingPathComponent(payloadReference.rawValue)
    )
    try Data(#"{"status":"not-an-integer"}"#.utf8).write(
      to: directory.appendingPathComponent(metadataReference.rawValue)
    )
    let loader = FileSystemFixtureLoader(rootDirectory: directory)

    do {
      _ = try await loader.load(payloadReference)
      Issue.record("Expected invalid fixture metadata error.")
    } catch FixtureError.invalidMetadata(let reference, _) {
      #expect(reference == metadataReference)
    }
  }

}
