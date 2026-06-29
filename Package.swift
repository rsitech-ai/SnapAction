// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SnapAction",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "SnapAction", targets: ["SnapActionApp"]),
        .library(name: "SnapActionCore", targets: ["SnapActionCore"])
    ],
    targets: [
        .executableTarget(
            name: "SnapActionApp",
            dependencies: ["SnapActionCore"],
            path: "Sources/SnapActionApp"
        ),
        .target(
            name: "SnapActionCore",
            path: "Sources/SnapActionCore"
        ),
        .testTarget(
            name: "SnapActionCoreTests",
            dependencies: ["SnapActionCore"],
            path: "Tests/SnapActionCoreTests"
        )
    ]
)
