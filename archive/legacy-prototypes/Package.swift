// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PulsePlan",
    products: [
        .library(name: "PulsePlanCore", targets: ["PulsePlanCore"])
    ],
    targets: [
        .target(name: "PulsePlanCore"),
        .testTarget(name: "PulsePlanCoreTests", dependencies: ["PulsePlanCore"])
    ]
)
