// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "pr-bar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "pr-bar", path: "Sources/pr-bar")
    ]
)
