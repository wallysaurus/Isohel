// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Isohel",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Isohel",
            type: .dynamic,
            targets: ["Isohel"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.42.1")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Isohel",
            dependencies: ["NIO",
                           "NIOHTTP1",
                           "NIOWebSocket"]),
        .testTarget(
            name: "IsohelTests",
            dependencies: ["Isohel"]),
    ]
)
