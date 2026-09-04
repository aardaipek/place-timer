// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PlaceTimer",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PlaceTimerCore", targets: ["PlaceTimerCore"]),
        .library(name: "PlaceTimerKit", targets: ["PlaceTimerKit"]),
        .executable(name: "PlaceTimerApp", targets: ["PlaceTimerApp"]),
    ],
    targets: [
        // Saf mantık: sistem çerçevesi yok, tamamen test edilebilir.
        .target(name: "PlaceTimerCore"),
        // Sistem sarmalayıcıları ve arayüz.
        .target(name: "PlaceTimerKit", dependencies: ["PlaceTimerCore"]),
        // Yalnızca giriş noktası; tüm davranış PlaceTimerKit'te.
        .executableTarget(name: "PlaceTimerApp", dependencies: ["PlaceTimerKit"]),
        .testTarget(name: "PlaceTimerCoreTests", dependencies: ["PlaceTimerCore"]),
    ]
)
