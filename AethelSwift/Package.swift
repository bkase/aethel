// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AethelSwift",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "AethelCore",
            targets: ["AethelCore"]
        ),
        .executable(
            name: "aethel",
            targets: ["AethelCLI"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "AethelCore",
            dependencies: ["Yams"]
        ),
        .executableTarget(
            name: "AethelCLI",
            dependencies: [
                "AethelCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "AethelCoreTests",
            dependencies: ["AethelCore"]
        ),
        .testTarget(
            name: "GoldenTests",
            dependencies: ["AethelCore", "AethelCLI"]
        )
    ]
)