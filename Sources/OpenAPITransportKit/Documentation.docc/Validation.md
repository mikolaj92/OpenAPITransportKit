# Validation

The package has two validation layers:

- root package tests for the transport kit itself;
- a separate generated-client integration package that uses
  `swift-openapi-generator`.

Both layers use Swift Testing (`Testing`, `@Suite`, `@Test`, `#expect`,
`#require`) only.

## Generated Client Proof

`IntegrationTests/GeneratedClient` contains:

- `openapi.yaml`
- `openapi-generator-config.yaml`
- tests using the real generated `Client`

The build plugin generates client code during:

```console
swift test --package-path IntegrationTests/GeneratedClient
```

The tests verify:

- request serialization reaches the transport as `HTTPRequest`;
- `operationID` is passed into the provider;
- JSON responses deserialize into generated DTOs;
- generated status handling works for success and error responses.

## Local Commands

```console
swift package dump-package
swift test
swift test --package-path IntegrationTests/GeneratedClient
swift build -c release
swift test -c release
```

## What Is Not Proved Locally

Local macOS tests do not prove:

- Linux runner setup;
- Android Swift SDK setup;
- package index rendering;
- GitHub-hosted Swift 6.3.2 availability.

These need separate platform checks.
