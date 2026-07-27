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
            resources: [.process("Resources")]
        ),
        .testTarget(name: "LodeRunnerTests", dependencies: ["LodeRunner"]),
        .executableTarget(
            name: "lr",
            dependencies: [
                "LodeRunner",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(name: "lrTests", dependencies: ["lr"]),
    ]
)
