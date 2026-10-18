# Validation

The package has two Swift validation layers:

- root package tests for the transport kit itself;
- a separate generated-client integration package that uses
  `swift-openapi-generator`.

Both layers use Swift Testing (`Testing`, `@Suite`, `@Test`, `#expect`,
`#require`) only. Documentation checks in `python/tests` use pytest.

## Generated Client Proof

The build plugin in `IntegrationTests/GeneratedClient` generates the real
`Client` from `openapi.yaml`. Three tests use that client: Dynamic GET checks
request serialization (method, path, query), `operationID`, and JSON response
deserialization; Fixture 200 and 400 check generated DTOs and success and error
status handling. They do not cover generated-client integration for Replay,
Stateful, Recording, or Multiplexing.

## Local Commands

```console
swift test
swift test --package-path IntegrationTests/GeneratedClient
swift build -c release
swift test -c release
swift test -c release --package-path IntegrationTests/GeneratedClient
uv run --extra dev pytest
```

## What Is Not Proved Locally

Local macOS tests do not prove:

- Linux runner setup;
- Android Swift SDK setup;
- package index rendering.

These need separate platform checks.
