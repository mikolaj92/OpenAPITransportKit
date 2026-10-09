# Contributing

This package targets Swift 6.3 or newer.

## Development

Run the full local checks before opening a pull request:

```console
swift test
swift test --package-path IntegrationTests/GeneratedClient
swift build -c release
swift test -c release
uv run --extra dev pytest
```

Swift tests must use Swift Testing (`Testing`, `@Suite`, `@Test`, `#expect`,
`#require`) only.

The pytest suite under `python/tests/` is part of this gate, not an optional
script: it guards documentation contracts such as the package identity in
`README.md`, `GettingStarted.md`, and `Package.swift`.

## API Rules

- Keep the primary integration point as `ClientTransport`.
- Do not depend on UI frameworks or app architectures.
- Do not introduce server frameworks.
- Keep public APIs `Sendable`-safe.
- Prefer protocol-based extension points over closed enums, except for `TransportSource`.
- Keep `TransportSource` a closed typed enum (`live`, `fixtures`, `replay`, `dynamic`, `stateful`). Do not add cases or a string-keyed registry; custom selection belongs in a user-provided `TransportSelector`.
- Preserve generated-client behavior: request serialization, response deserialization, and status handling.

## Compatibility

The package follows SemVer after `1.0.0`.

Before `1.0.0`, source-breaking changes are allowed when they simplify the long-term API.
