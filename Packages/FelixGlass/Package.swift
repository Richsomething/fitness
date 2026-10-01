// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FelixGlass",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "FelixGlass", targets: ["FelixGlass"]),
    ],
    targets: [
        .target(name: "FelixGlass"),
        .testTarget(name: "FelixGlassTests", dependencies: ["FelixGlass"]),
    ],
    // The library is plain SwiftUI value code; the app it came from builds in Swift 5 mode.
    swiftLanguageModes: [.v5]
)
