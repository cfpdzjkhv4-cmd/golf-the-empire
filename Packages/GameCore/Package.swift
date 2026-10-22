// swift-tools-version: 6.0
// GameCore: every rule of Golf: The Empire, with no SpriteKit or SwiftUI.
// Runs headless, so `swift test` replays whole game days on a Mac or in CI.
// CourseArt: the house style and how holes are drawn, as plain instructions
// any renderer can follow (CoreGraphics in the app, SVG for previews).

import PackageDescription

let package = Package(
    name: "GameCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "GameCore", targets: ["GameCore"]),
        .library(name: "CourseArt", targets: ["CourseArt"]),
    ],
    targets: [
        .target(
            name: "GameCore",
            resources: [.copy("Resources/Data")]
        ),
        .target(
            name: "CourseArt",
            dependencies: ["GameCore"],
            resources: [.copy("Resources/style.json")]
        ),
        .executableTarget(
            name: "art-preview",
            dependencies: ["GameCore", "CourseArt"]
        ),
        .testTarget(
            name: "GameCoreTests",
            dependencies: ["GameCore"]
        ),
        .testTarget(
            name: "CourseArtTests",
            dependencies: ["GameCore", "CourseArt"]
        ),
    ]
)
