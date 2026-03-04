// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Orbit",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "Orbit",
            path: "Orbit",
            exclude: ["Info.plist"],
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"
                ])
            ]
        )
    ]
)
