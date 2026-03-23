// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "IdleEngine",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "IdleEngine", targets: ["IdleEngine"])
    ],
    targets: [
        .target(
            name: "IdleEngine",
            path: "Sources/IdleEngine",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "IdleEngineTests",
            dependencies: ["IdleEngine"],
            path: "Tests/IdleEngineTests"
        )
    ]
)
