// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LowCor",
    platforms: [.macOS(.v13)],
    products: [.library(name: "LowCorCore", targets: ["LowCorCore"])],
    targets: [
        .target(name: "LowCorCore", path: "ios/LowCor/Core"),
        .testTarget(name: "LowCorCoreTests", dependencies: ["LowCorCore"])
    ]
)
