# Contributing

This package targets Swift 6.3 or newer.

## Development

Run the full local checks before opening a pull request:

```console
swift test
swift test --package-path IntegrationTests/GeneratedClient
swift build -c release
swift test -c release
```

Tests must use Swift Testing (`Testing`, `@Suite`, `@Test`, `#expect`,
`#require`) only.

## API Rules

- Keep the primary integration point as `ClientTransport`.
- Do not depend on UI frameworks or app architectures.
- Do not introduce server frameworks.
- Keep public APIs `Sendable`-safe.
- Prefer protocol-based extension points over closed enums.
- Preserve generated-client behavior: request serialization, response deserialization, and status handling.

## Compatibility

The package follows SemVer after `1.0.0`.

Before `1.0.0`, source-breaking changes are allowed when they simplify the long-term API.
