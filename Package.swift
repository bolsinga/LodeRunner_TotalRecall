// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LodeRunnerCore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "LodeRunnerCore", targets: ["LodeRunnerCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0")
    ],
    targets: [
        .target(name: "LodeRunnerCore"),
        .testTarget(name: "LodeRunnerCoreTests", dependencies: ["LodeRunnerCore"]),
        .executableTarget(
            name: "lr-leveltool",
            dependencies: [
                "LodeRunnerCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(name: "lr-leveltoolTests", dependencies: ["lr-leveltool"]),
        .executableTarget(
            name: "lr-runnertool",
            dependencies: [
                "LodeRunnerCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(name: "lr-runnertoolTests", dependencies: ["lr-runnertool"]),
    ]
)
