# swift-openapi-transport-kit

Alternative `ClientTransport` implementations and adapters for Apple
`swift-openapi-generator` / `OpenAPIRuntime`.

This package is not a test framework, mock server, or app architecture layer.
The only integration point is `ClientTransport`.

## Requirements

- Swift 6.3 or newer.
- `OpenAPIRuntime` 1.12.0 or newer.
- `HTTPTypes` 1.5.1 or newer.

The package intentionally targets the latest Swift toolchain only. Deployment
targets remain aligned with `OpenAPIRuntime`.

`swift-openapi-generator` is used only by the generated-client integration
package. It is not a runtime dependency of the main library package.

## Modules

- `OpenAPITransportKitCore`: provider adapter, multiplexing transport, routing primitives.
- `OpenAPITransportKitFixtures`: operationId-based fixture responses.
- `OpenAPITransportKitReplay`: replay stores, request fingerprinting, and recording middleware.
- `OpenAPITransportKitDynamic`: closure-based dynamic responses.
- `OpenAPITransportKitStateful`: actor-backed stateful response providers.
- `OpenAPITransportKit`: umbrella module.

## Fixture Example

```swift
import OpenAPITransportKit

let fixtureProvider = FixtureResponseProvider(
    loader: MemoryFixtureLoader(fixtures: [
        "getDashboard.success.json": FixturePayload(string: #"{"items":[]}"#)
    ]),
    scenarioProvider: StaticScenarioProvider(.success)
)

let client = Client(
    serverURL: URL(string: "https://example.com")!,
    transport: ProviderTransport(provider: fixtureProvider)
)
```

The generated client still performs request serialization, response
deserialization, status-code handling, and DTO mapping. The fixture transport
only replaces the HTTP response source.

Fixture sidecar metadata is supported:

```text
getDashboard.success.json
getDashboard.success.meta.json
```

```json
{
  "status": 202,
  "headers": {
    "Content-Type": "application/json"
  }
}
```

For repeated headers, use `headerFields`:

```json
{
  "headerFields": [
    { "name": "Set-Cookie", "value": "a=1" },
    { "name": "Set-Cookie", "value": "b=2" }
  ]
}
```

## Dynamic Example

```swift
let transport = DynamicTransport(
    provider: ClosureResponseProvider { context in
        TransportResponse(status: .ok, body: HTTPBody(#"{"ok":true}"#))
    }
)
```

## Routing Example

```swift
let transport = MultiplexingTransport(
    selector: RoutingTransportSelector(
        identifierProvider: ClosureTransportIdentifierProvider { _ in "fixtures" },
        routes: [
            "fixtures": ProviderTransport(provider: fixtureProvider),
            "live": URLSessionTransport()
        ]
    )
)
```

## Replay Example

```swift
let store = FileReplayStore(rootDirectory: replayDirectory)
let keyStrategy = FingerprintedReplayKeyStrategy(
    fingerprinter: StableRequestFingerprinter(includedHeaderNames: ["Accept"])
)

let replayProvider = ReplayResponseProvider(
    store: store,
    keyStrategy: keyStrategy
)
```

## Recording Example

```swift
let recorder = RecordingClientMiddleware(
    writer: FileReplayStore(rootDirectory: replayDirectory),
    keyStrategy: OperationIDReplayKeyStrategy()
)

let client = Client(
    serverURL: URL(string: "https://example.com")!,
    transport: liveTransport,
    middlewares: [recorder]
)
```

## Dependency Note

`OpenAPIRuntime.ClientTransport` exposes `HTTPRequest` and `HTTPResponse`,
which are defined by Apple's `swift-http-types` package. This package imports
`HTTPTypes` directly where those public types are used.

## Current Coverage

The root test suite covers the transport layers without pulling in
`swift-openapi-generator`.

Generated-client proof lives in `IntegrationTests/GeneratedClient`. It uses the
build plugin to generate a real OpenAPI client from `openapi.yaml` and verifies:

- query serialization reaches the transport as an `HTTPRequest`;
- `operationID` is passed to the response provider;
- JSON responses deserialize into generated DTOs;
- generated status-code handling works for success and error responses.

## Remaining Work

- Treat GitHub Actions as an experimental template until hosted runners have the required Swift 6.3.2 toolchain.
- Run the manual Android SDK smoke job once a matching SDK artifact URL and checksum are selected.
- Stabilize API names before `1.0.0`.
