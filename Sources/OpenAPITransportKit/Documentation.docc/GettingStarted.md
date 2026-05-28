# Getting Started

Create a generated OpenAPI client and replace only its transport.

## Add The Package

Use the umbrella product when starting:

```swift
.package(url: "https://github.com/<owner>/swift-openapi-transport-kit.git", from: "0.1.0")
```

```swift
.product(name: "OpenAPITransportKit", package: "swift-openapi-transport-kit")
```

Use the split products later if a package wants a narrower dependency surface.

## Create A Fixture Transport

```swift
import Foundation
import OpenAPITransportKit

let transport = FixtureTransport(
    loader: MemoryFixtureLoader(fixtures: [
        "getDashboard.success.json": FixturePayload(
            string: #"{"items":["one","two"]}"#
        )
    ])
)
```

The fixture key is based on the OpenAPI `operationId`, not on the request URL.

## Use The Generated Client

```swift
let client = Client(
    serverURL: URL(string: "https://example.com/api")!,
    transport: transport
)

let response = try await client.getDashboard()
let dashboard = try response.ok.body.json
```

The generated client still serializes the request, deserializes the response,
handles status codes, and returns generated DTOs.

## Switch Response Sources

Use ``MultiplexingTransport`` when an app needs runtime switching.

```swift
let transport = MultiplexingTransport(
    selector: SourceSwitchingTransportSelector(
        sourceProvider: ClosureTransportSourceProvider { _ in .fixtures },
        registry: TransportSourceRegistry(
            live: liveTransport,
            fixtures: fixtureTransport,
            replay: replayTransport,
            dynamic: dynamicTransport
        )
    )
)
```

The library does not own that mode selection. It can come from command-line
arguments, environment, app settings, dependency injection, or any other app
mechanism.

## Validate Locally

This package uses Swift 6.3 as the baseline.

```console
swift test
swift test --package-path IntegrationTests/GeneratedClient
swift build -c release
swift test -c release
```
