// swift-tools-version: 6.2

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "UIEnvironments",
    platforms: [.iOS(.v13), .macOS(.v10_15)],
    products: [
        .library(
            name: "UIEnvironments",
            targets: ["UIEnvironments"],
        ),
        .library(
            name: "UIEnvironmentsMacros",
            targets: ["UIEnvironmentsMacros"],
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax", from: "602.0.0"),
    ],
    targets: [
        .target(
            name: "UIEnvironments",
        ),
        .target(
            name: "UIEnvironmentsMacros",
            dependencies: [
                "UIEnvironments",
                "_UIEnvironmentsMacros",
            ],
        ),
        .macro(
            name: "_UIEnvironmentsMacros",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ],
        ),
        .testTarget(
            name: "UIEnvironmentTests",
            dependencies: ["UIEnvironments"],
        ),
    ]
)
