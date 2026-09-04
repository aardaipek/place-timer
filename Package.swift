// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PlaceTimerCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PlaceTimerCore", targets: ["PlaceTimerCore"])
    ],
    targets: [
        .target(name: "PlaceTimerCore"),
        .testTarget(name: "PlaceTimerCoreTests", dependencies: ["PlaceTimerCore"]),
    ]
)
