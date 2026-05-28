# Release Policy

This package uses SemVer.

## Versioning

- Patch: bug fixes and documentation changes.
- Minor: additive API and new transport/provider modules.
- Major: source-breaking API changes.

## Swift Baseline

The package tracks the latest stable Swift toolchain. Current baseline: Swift 6.3.

Older Swift toolchains are not supported.

## OpenAPI Runtime Compatibility

The public integration surface follows `OpenAPIRuntime.ClientTransport` and
`OpenAPIRuntime.ClientMiddleware`.

When `OpenAPIRuntime` changes these protocols, this package should isolate the
required adaptation in the transport and middleware adapters.

## Pre-Release Checklist

```console
swift test
swift test --package-path IntegrationTests/GeneratedClient
swift build -c release
swift test -c release
```

Also verify CI on macOS and Linux.

Android SDK smoke builds are manual until Swift SDK artifact URLs and checksums
are stable enough for unattended CI.
