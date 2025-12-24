// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FolderBar",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "FolderBarCore",
            targets: ["FolderBarCore"]
        ),
        .executable(
            name: "FolderBar",
            targets: ["FolderBar"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.8.1")
    ],
    targets: [
        .target(
            name: "FolderBarCore"
        ),
        .executableTarget(
            name: "FolderBar",
            dependencies: [
                "FolderBarCore",
                .product(name: "Sparkle", package: "Sparkle")
            ]
        ),
        .testTarget(
            name: "FolderBarTests",
            dependencies: ["FolderBarCore"]
        )
    ]
)
