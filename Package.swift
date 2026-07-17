// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LoveWidget",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(path: "LoveWidgetCore"),
    ],
    targets: [
        .executableTarget(
            name: "LoveWidget",
            dependencies: [
                .product(name: "LoveWidgetCore", package: "LoveWidgetCore"),
            ],
            path: "App",
            swiftSettings: [
                .unsafeFlags(["-strict-concurrency=complete"]),
            ]
        ),
    ]
)
