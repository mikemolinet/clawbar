// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClawBarCore",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "ClawBarCore", targets: ["ClawBarCore"]),
    ],
    targets: [
        .target(
            name: "ClawBarCore",
            path: "Sources",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
    ]
)
