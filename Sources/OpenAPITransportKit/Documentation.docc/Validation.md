# Validation

The package has two Swift validation layers:

- root package tests for the transport kit itself;
- a separate generated-client integration package that uses
  `swift-openapi-generator`.

Both layers use Swift Testing (`Testing`, `@Suite`, `@Test`, `#expect`,
`#require`) only. Documentation checks in `python/tests` use pytest.

## Generated Client Proof

`IntegrationTests/GeneratedClient` contains:

- `openapi.yaml`
- `openapi-generator-config.yaml`
- tests using the real generated `Client`

The build plugin generates client code during:

```console
swift test --package-path IntegrationTests/GeneratedClient
```

The three tests cover the real generated `Client` only with `DynamicTransport`
and `FixtureTransport`:

- Dynamic GET verifies the GET method, `/greet` path, `name=Blob` query parameter,
  `operationID`, and JSON response deserialization;
- Fixture 200 verifies JSON deserialization into generated DTOs and success status handling;
- Fixture 400 verifies JSON deserialization and error status handling.

These tests do not establish generated-client integration for `ReplayTransport`,
`StatefulTransport`, `RecordingClientMiddleware`, or `MultiplexingTransport`;
this does not imply those components are broken.

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
