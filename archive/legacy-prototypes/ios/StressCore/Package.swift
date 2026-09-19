// swift-tools-version: 5.9
import PackageDescription

// Deliberately declares no `platforms:` restriction. StressCore imports nothing
// from SwiftUI, UIKit, or Swift Charts, so it compiles and tests on any host
// with a Swift toolchain — including Windows, which is where this package's
// tests are currently run. Keep it that way: the moment a UI type leaks in
// here, the detector stops being verifiable off a Mac.
let package = Package(
    name: "StressCore",
    // Required despite the note above. `platforms:` constrains Apple targets
    // only — SwiftPM ignores it on Windows and Linux, so the cross-platform
    // property is untouched. Omitting it does NOT mean "no constraint": it
    // means SwiftPM falls back to macOS 10.13 / iOS 11, where async/await,
    // Task and Duration do not exist. Windows has no availability model, so
    // that failure is invisible here and only appears on an Apple toolchain.
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "StressCore", targets: ["StressCore"])
    ],
    targets: [
        .target(name: "StressCore"),
        // Runs the whole pipeline in a terminal. Exists because the SwiftUI
        // screen cannot be launched without a Mac, and "the detector passes
        // its tests" is a weaker claim than seeing the day rendered.
        .executableTarget(name: "StressDemo", dependencies: ["StressCore"]),
        .testTarget(name: "StressCoreTests", dependencies: ["StressCore"])
    ]
)
