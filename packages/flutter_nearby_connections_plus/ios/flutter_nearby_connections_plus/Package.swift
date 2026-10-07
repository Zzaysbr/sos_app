// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "flutter_nearby_connections_plus",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "flutter-nearby-connections-plus",
            targets: ["flutter_nearby_connections_plus"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/google/nearby.git",
            exact: "0.0.1-ios"
        )
    ],
    targets: [
        .target(
            name: "flutter_nearby_connections_plus",
            dependencies: [
                .product(
                    name: "NearbyConnections",
                    package: "nearby"
                )
            ],
            path: "Sources/flutter_nearby_connections_plus"
        )
    ]
)