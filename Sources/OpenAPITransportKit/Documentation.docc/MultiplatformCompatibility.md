# Multiplatform Compatibility

OpenAPITransportKit is designed for Swift Multiplatform.

## Supported Baseline

The package targets Swift 6.3 or newer.

The code uses:

- Swift Standard Library
- Foundation
- OpenAPIRuntime
- HTTPTypes

The core package does not use SwiftUI, UIKit, AppKit, Vapor, TCA, or other
application frameworks.

## Platforms

The Apple deployment targets declared in `Package.swift` are:

- iOS 13+
- macOS 10.15+
- Mac Catalyst 13+
- tvOS 13+
- watchOS 6+
- visionOS 1+

Linux and Android are also supported, but they do not have deployment-target
entries in SwiftPM's Apple `platforms` list. Android builds use Swift SDKs; see
[Android](#android) below.

## HTTPTypes Dependency

`ClientTransport` exposes `HTTPRequest`, `HTTPResponse`, and `HTTPFields`.
Those types are defined in `HTTPTypes`, so this package imports `HTTPTypes`
directly.

This is not optional with Swift 6 import visibility.

## Continuous Integration

This repository does not ship GitHub Actions workflows. Local validation is
the authoritative gate.

```console
swift test
swift test --package-path IntegrationTests/GeneratedClient
swift build -c release
swift test -c release
```

## Android

Android builds require a matching Swift SDK artifact bundle and checksum.

After installing an SDK:

```console
swift build --swift-sdk aarch64-unknown-linux-android28
```

Android smoke testing should remain manual until the project chooses a stable
SDK artifact source.
