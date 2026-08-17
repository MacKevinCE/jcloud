// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "jcloud",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "jcloud", path: "Sources")
    ]
)
