// swift-tools-version: 6.0
// GameCore: every rule of Golf: The Empire, with no SpriteKit or SwiftUI.
// Runs headless, so `swift test` replays whole game days on a Mac or in CI.

import PackageDescription

let package = Package(
    name: "GameCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "GameCore", targets: ["GameCore"]),
    ],
    targets: [
        .target(
            name: "GameCore",
            resources: [.copy("Resources/Data")]
        ),
        .testTarget(
            name: "GameCoreTests",
            dependencies: ["GameCore"]
        ),
    ]
)
