// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PRBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "PRBar", path: "Sources/PRBar")
    ]
)
