// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "GameCenter",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "GameCenter",
            path: "Sources/GameCenter"
        )
    ]
)
