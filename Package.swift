// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "autokbisw",
    products: [
        .executable(name: "autokbisw", targets: ["autokbisw"]),
        .library(name: "AutokbiswCore", targets: ["AutokbiswCore"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "AutokbiswCore",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .target(
            name: "autokbisw",
            dependencies: ["AutokbiswCore"]
        ),
        .testTarget(
            name: "autokbiswTests",
            dependencies: ["AutokbiswCore"]
        ),
    ]
)
