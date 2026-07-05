// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "aprelayadmin",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .executable(
            name: "aprelayadmin",
            targets: ["APRelayAdmin"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/minacle/RetortTUI",
            branch: "main"
        ),
        .package(
            url: "https://github.com/swift-server/async-http-client.git",
            from: "1.34.0"
        ),
        .package(
            url: "https://github.com/apple/swift-nio.git",
            from: "2.101.0"
        ),
    ],
    targets: [
        .executableTarget(
            name: "APRelayAdmin",
            dependencies: [
                .product(
                    name: "AsyncHTTPClient",
                    package: "async-http-client"
                ),
                .product(
                    name: "NIOCore",
                    package: "swift-nio"
                ),
                "RetortTUI",
            ]
        ),
        .testTarget(
            name: "APRelayAdminTests",
            dependencies: [
                "APRelayAdmin",
                .product(
                    name: "AsyncHTTPClient",
                    package: "async-http-client"
                ),
                .product(
                    name: "NIOCore",
                    package: "swift-nio"
                ),
                .product(
                    name: "NIOHTTP1",
                    package: "swift-nio"
                ),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
