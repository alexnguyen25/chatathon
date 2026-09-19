// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LowCor",
    products: [
        .library(name: "LowCorCore", targets: ["LowCorCore"])
    ],
    targets: [
        .target(name: "LowCorCore"),
        .testTarget(name: "LowCorCoreTests", dependencies: ["LowCorCore"])
    ]
)
