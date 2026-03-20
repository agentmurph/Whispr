// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Whispr",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Whispr", targets: ["Whispr"])
    ],
    dependencies: [
        .package(url: "https://github.com/exPHAT/SwiftWhisper.git", branch: "master"),
        .package(url: "https://github.com/soffes/HotKey.git", from: "0.2.0"),
    ],
    targets: [
        .executableTarget(
            name: "Whispr",
            dependencies: [
                "SwiftWhisper",
                "HotKey",
            ],
            path: "Sources/Whispr"
        )
    ]
)
