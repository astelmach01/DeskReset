// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DeskReset",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "DeskResetCore", targets: ["DeskResetCore"]),
        .executable(name: "DeskReset", targets: ["DeskReset"]),
        .executable(name: "deskresetctl", targets: ["DeskResetCtl"])
    ],
    targets: [
        .target(name: "DeskResetCore"),
        .executableTarget(
            name: "DeskReset",
            dependencies: ["DeskResetCore"]
        ),
        .executableTarget(
            name: "DeskResetCtl",
            dependencies: ["DeskResetCore"]
        ),
        .executableTarget(
            name: "DeskResetCoreChecks",
            dependencies: ["DeskResetCore"]
        )
    ]
)
