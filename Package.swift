// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "NotchVeil",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(name: "NotchVeilCore", targets: ["NotchVeilCore"]),
        .executable(name: "NotchVeil", targets: ["NotchVeil"]),
        .executable(name: "NotchVeilLoginLauncher", targets: ["NotchVeilLoginLauncher"])
    ],
    targets: [
        .target(name: "NotchVeilCore"),
        .executableTarget(
            name: "NotchVeil",
            dependencies: ["NotchVeilCore"],
            path: "Sources/NotchVeil"
        ),
        .executableTarget(
            name: "NotchVeilLoginLauncher",
            path: "Sources/LoginLauncher"
        ),
        .testTarget(
            name: "NotchVeilCoreTests",
            dependencies: ["NotchVeilCore"]
        )
    ]
)
