// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ring",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ring",
            path: "Sources/ring"
        )
    ]
)
