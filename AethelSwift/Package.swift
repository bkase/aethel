// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "A4Swift",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .watchOS(.v9),
        .tvOS(.v16),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "A4CoreSwift",
            targets: ["A4CoreSwift"]
        )
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "A4CoreSwift",
            dependencies: []
        ),
        .testTarget(
            name: "A4CoreSwiftTests",
            dependencies: ["A4CoreSwift"]
        ),
        .testTarget(
            name: "A4GoldenParityTests",
            dependencies: ["A4CoreSwift"]
        )
    ]
)