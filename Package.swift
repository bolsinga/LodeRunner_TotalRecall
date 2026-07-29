// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LodeRunner",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "LodeRunner", targets: ["LodeRunner"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0")
    ],
    targets: [
        .target(
            name: "LodeRunner",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            resources: [
                .process("Resources/Tiles.xcassets"),
                // `.copy` preserves the theme-subdirectory layout so
                // `Bundle.module.url(..., subdirectory: "Sounds/Apple2")`
                // resolves — a `.process` rule would flatten every
                // `<theme>/born.mp3` into a single bundle-root `born.mp3` and
                // collide across themes.
                .copy("Resources/Sounds"),
                // Same reason: `Bundle.module.url(..., subdirectory: "Levels")`
                // in `LevelPack.load()` needs the directory preserved.
                .copy("Resources/Levels"),
            ]
        ),
        .testTarget(name: "LodeRunnerTests", dependencies: ["LodeRunner"]),
        .executableTarget(
            name: "lr",
            dependencies: [
                "LodeRunner",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
    ]
)
