# Fixtures

Fixture transport serves local response bodies keyed by OpenAPI `operationId`.

## Naming

The default fixture resolver uses:

```text
<operationID>.<scenario>.json
```

Examples:

```text
getDashboard.success.json
getDashboard.empty.json
getDashboard.error.json
```

## Scenarios

Use ``OpenAPITransportKitFixtures/StaticScenarioProvider`` for a fixed scenario.

```swift
let transport = FixtureTransport(
    loader: loader,
    scenario: .success
)
```

Use ``OpenAPITransportKitFixtures/ClosureScenarioProvider`` when scenario
selection depends on runtime context.

```swift
let scenarioProvider = ClosureScenarioProvider { context in
    context.request.headerFields[HTTPField.Name("X-Scenario")!] == "empty"
        ? .empty
        : .success
}
```

## Metadata Sidecars

A fixture can have an optional metadata sidecar:

```text
getDashboard.success.json
getDashboard.success.meta.json
```

```json
{
  "status": 202,
  "reasonPhrase": "Accepted",
  "headers": {
    "X-Fixture": "dashboard-success"
  }
}
```

If metadata is missing, ``OpenAPITransportKitFixtures/FixtureResponseProvider`` uses
``OpenAPITransportKitFixtures/FixtureResponseDefaults``. The default is JSON `200 OK`.

Metadata headers are merged with defaults. A sidecar that adds `X-Fixture` does
not remove the default `Content-Type: application/json`.

Use `headerFields` when repeated headers matter:

```json
{
  "headerFields": [
    { "name": "Set-Cookie", "value": "a=1" },
    { "name": "Set-Cookie", "value": "b=2" }
  ]
}
```

## Memory Loader

```swift
let loader = MemoryFixtureLoader(fixtures: [
    "getDashboard.success.json": FixturePayload(
        string: #"{"items":[]}"#
    )
])
```

Memory fixtures are useful in unit tests and examples.

## File System Loader

```swift
let loader = FileSystemFixtureLoader(rootDirectory: fixturesDirectory)
```

Use this in command-line tools, local development, and server-side Swift.

## Bundle Loader

```swift
let loader = BundleFixtureLoader(
    bundle: .module,
    subdirectory: "Fixtures"
)
```

Use this with SwiftPM resources or app bundles. On non-Apple platforms, this
still uses Foundation `Bundle` support.

Lookup is single-path and fail-closed: a missing subdirectory resource fails
instead of silently loading a root resource. Pass `subdirectory: nil` when
fixtures live at the bundle root.

With SwiftPM, prefer `.copy("…/Fixtures")` when you need a stable subdirectory.
`.process` flattens unprocessed files to the resource-bundle root, so a
`subdirectory` lookup will not find them there.

## Missing Fixtures

Missing fixtures throw `FixtureError.missingFixture(_:)`. They do not return
HTTP `404`, because the problem is fixture configuration, not backend behavior.

## Custom Resolvers

Implement ``OpenAPITransportKitFixtures/FixtureResolver`` to use another naming scheme.

```swift
struct DirectoryFixtureResolver: FixtureResolver {
    func reference(
        for context: TransportRequestContext,
        scenario: FixtureScenario
    ) async throws -> FixtureReference {
        FixtureReference(rawValue: "\(context.operationID)/\(scenario.rawValue).json")
    }
}
```
