// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FolderBar",
    platforms: [
        .macOS(.v11),
    ],
    products: [
        .library(
            name: "FolderBarCore",
            targets: ["FolderBarCore"]
        ),
        .executable(
            name: "FolderBar",
            targets: ["FolderBar"]
        ),
    ],
    targets: [
        .target(
            name: "FolderBarCore"
        ),
        .executableTarget(
            name: "FolderBar",
            dependencies: ["FolderBarCore"]
        ),
        .testTarget(
            name: "FolderBarTests",
            dependencies: ["FolderBarCore"]
        ),
    ]
)
