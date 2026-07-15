// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "NotchVeil",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(name: "HeaderCore", targets: ["HeaderCore"]),
        .executable(name: "NotchVeil", targets: ["NotchVeil"]),
        .executable(name: "NotchVeilLoginLauncher", targets: ["NotchVeilLoginLauncher"])
    ],
    targets: [
        .target(name: "HeaderCore"),
        .executableTarget(
            name: "NotchVeil",
            dependencies: ["HeaderCore"],
            path: "Sources/Header"
        ),
        .executableTarget(
            name: "NotchVeilLoginLauncher",
            path: "Sources/LoginLauncher"
        ),
        .testTarget(
            name: "HeaderCoreTests",
            dependencies: ["HeaderCore"]
        )
    ]
)
