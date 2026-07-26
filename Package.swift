// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LodeRunnerCore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "LodeRunnerCore", targets: ["LodeRunnerCore"]),
        .library(name: "LodeRunnerUI", targets: ["LodeRunnerUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0")
    ],
    targets: [
        .target(name: "LodeRunnerCore"),
        .testTarget(name: "LodeRunnerCoreTests", dependencies: ["LodeRunnerCore"]),
        .target(
            name: "LodeRunnerUI",
            dependencies: ["LodeRunnerCore"],
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "lr",
            dependencies: [
                "LodeRunnerCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(name: "lrTests", dependencies: ["lr"]),
    ]
)
