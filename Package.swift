// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "UIEnvironments",
    platforms: [.iOS(.v13)],
    products: [
        .library(
            name: "UIEnvironments",
            targets: ["UIEnvironments"],
        ),
    ],
    dependencies: [],
    targets: [
        .target(name: "UIEnvironments"),
        .testTarget(
            name: "UIEnvironmentTests",
            dependencies: ["UIEnvironments"],
        ),
    ]
)
