// swift-tools-version: 6.0
// LoveWidgetCore — Shared business logic for the LoveWidget app and widget extension.
// Both the main app and WidgetKit extension depend on this package.

import PackageDescription

let package = Package(
    name: "LoveWidgetCore",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "LoveWidgetCore",
            targets: ["LoveWidgetCore"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/supabase/supabase-swift.git",
            from: "2.0.0"
        ),
    ],
    targets: [
        .target(
            name: "LoveWidgetCore",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift"),
            ],
            path: "Sources/LoveWidgetCore",
            resources: [
                .copy("Supabase/migrations"),
            ],
            swiftSettings: [
                .unsafeFlags(["-strict-concurrency=complete"]),
            ],
            linkerSettings: [
                // IOKit needed for hardware device UUID in DeviceIdentifier
                .linkedFramework("IOKit", .when(platforms: [.macOS])),
            ]
        ),
        .testTarget(
            name: "LoveWidgetCoreTests",
            dependencies: ["LoveWidgetCore"],
            path: "Tests/LoveWidgetCoreTests",
            swiftSettings: [
                .unsafeFlags(["-strict-concurrency=complete"]),
            ]
        ),
    ]
)
