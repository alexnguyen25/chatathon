// swift-tools-version: 5.9
import PackageDescription

// Separate from StressCore on purpose. This target imports SwiftUI and Swift
// Charts, so it can only build on macOS with the iOS SDK. StressCore stays a
// plain package with no platform floor so the detector remains testable on any
// host — see ../scripts/swift-env.ps1.
let package = Package(
    name: "StressMonitorUI",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "StressMonitorUI", targets: ["StressMonitorUI"])
    ],
    dependencies: [
        .package(path: "../StressCore")
    ],
    targets: [
        .target(
            name: "StressMonitorUI",
            dependencies: [.product(name: "StressCore", package: "StressCore")]
        )
    ]
)
