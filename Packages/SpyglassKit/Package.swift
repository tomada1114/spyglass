// swift-tools-version: 6.2
import PackageDescription

/// Strictness from day one: Swift 6 language mode (data-race safety as errors)
/// and every warning treated as an error. There is never a "legacy" codebase.
let strictSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .treatAllWarnings(as: .error),
]

let package = Package(
    name: "SpyglassKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SpyglassCore", targets: ["SpyglassCore"]),
        .library(name: "SpyglassUI", targets: ["SpyglassUI"]),
    ],
    targets: [
        .target(name: "SpyglassCore", swiftSettings: strictSettings),
        .target(
            name: "SpyglassUI",
            dependencies: ["SpyglassCore"],
            resources: [.process("Assets.xcassets")],
            swiftSettings: strictSettings,
        ),
        .testTarget(
            name: "SpyglassCoreTests",
            dependencies: ["SpyglassCore"],
            swiftSettings: strictSettings,
        ),
    ],
)
