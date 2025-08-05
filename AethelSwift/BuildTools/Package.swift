// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BuildTools",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-format", from: "600.0.0")
    ],
    targets: [
        .target(name: "BuildTools", path: "")
    ]
)