// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BaumAgent",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "BaumAgent",
            path: "BaumAgent",
            resources: [],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
    ]
)
