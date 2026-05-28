// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "swift-openapi-transport-kit",
    platforms: [
        .macOS(.v10_15),
        .macCatalyst(.v13),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "OpenAPITransportKit", targets: ["OpenAPITransportKit"]),
        .library(name: "OpenAPITransportKitCore", targets: ["OpenAPITransportKitCore"]),
        .library(name: "OpenAPITransportKitFixtures", targets: ["OpenAPITransportKitFixtures"]),
        .library(name: "OpenAPITransportKitReplay", targets: ["OpenAPITransportKitReplay"]),
        .library(name: "OpenAPITransportKitDynamic", targets: ["OpenAPITransportKitDynamic"]),
        .library(name: "OpenAPITransportKitStateful", targets: ["OpenAPITransportKitStateful"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-runtime.git", from: "1.12.0"),
        .package(url: "https://github.com/apple/swift-http-types.git", from: "1.5.1"),
    ],
    targets: [
        .target(
            name: "OpenAPITransportKitCore",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ]
        ),
        .target(
            name: "OpenAPITransportKitFixtures",
            dependencies: [
                "OpenAPITransportKitCore",
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ]
        ),
        .target(
            name: "OpenAPITransportKitReplay",
            dependencies: [
                "OpenAPITransportKitCore",
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ]
        ),
        .target(
            name: "OpenAPITransportKitDynamic",
            dependencies: [
                "OpenAPITransportKitCore",
            ]
        ),
        .target(
            name: "OpenAPITransportKitStateful",
            dependencies: [
                "OpenAPITransportKitCore",
            ]
        ),
        .target(
            name: "OpenAPITransportKit",
            dependencies: [
                "OpenAPITransportKitCore",
                "OpenAPITransportKitFixtures",
                "OpenAPITransportKitReplay",
                "OpenAPITransportKitDynamic",
                "OpenAPITransportKitStateful",
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ]
        ),
        .testTarget(
            name: "OpenAPITransportKitTests",
            dependencies: [
                "OpenAPITransportKitCore",
                "OpenAPITransportKitFixtures",
                "OpenAPITransportKitReplay",
                "OpenAPITransportKitDynamic",
                "OpenAPITransportKitStateful",
                "OpenAPITransportKit",
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ],
            resources: [
                .process("Resources")
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
