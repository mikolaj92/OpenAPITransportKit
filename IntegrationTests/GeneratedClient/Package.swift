// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "swift-openapi-transport-kit-generated-client-tests",
    platforms: [
        .macOS(.v10_15),
        .macCatalyst(.v13),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
        .visionOS(.v1),
    ],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/apple/swift-openapi-generator.git", from: "1.12.2"),
        .package(url: "https://github.com/apple/swift-openapi-runtime.git", from: "1.12.0"),
        .package(url: "https://github.com/apple/swift-http-types.git", from: "1.5.1"),
    ],
    targets: [
        .testTarget(
            name: "GeneratedClientTests",
            dependencies: [
                .product(name: "OpenAPITransportKit", package: "swift-openapi-transport-kit"),
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ],
            plugins: [
                .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")
            ]
        ),
    ]
)

for target in package.targets {
    var settings = target.swiftSettings ?? []
    settings.append(.enableUpcomingFeature("ExistentialAny"))
    settings.append(.enableUpcomingFeature("MemberImportVisibility"))
    settings.append(.enableUpcomingFeature("InternalImportsByDefault"))
    settings.append(.enableExperimentalFeature("StrictConcurrency=complete"))
    target.swiftSettings = settings
}
