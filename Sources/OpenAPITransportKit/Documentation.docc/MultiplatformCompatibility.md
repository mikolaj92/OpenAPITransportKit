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

Deployment targets follow `OpenAPIRuntime`:

- iOS
- macOS
- tvOS
- watchOS
- visionOS
- Linux
- Android through Swift SDKs

## HTTPTypes Dependency

`ClientTransport` exposes `HTTPRequest`, `HTTPResponse`, and `HTTPFields`.
Those types are defined in `HTTPTypes`, so this package imports `HTTPTypes`
directly.

This is not optional with Swift 6 import visibility.

## GitHub Actions Note

The workflow in this repository is a template, not the source of truth. Hosted
GitHub runners may not have the exact Swift 6.3.2 toolchain or Android SDK
setup needed by this package.

Use local validation as the authoritative gate until CI runners are pinned and
verified.

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
