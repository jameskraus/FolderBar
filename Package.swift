// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let strictConcurrencySwiftSettings: [SwiftSetting] = [
    .unsafeFlags([
        "-strict-concurrency=complete",
        "-warn-concurrency"
    ])
]

let actorDataRaceChecksSwiftSettings: [SwiftSetting] = [
    .unsafeFlags(
        [
            "-enable-actor-data-race-checks"
        ],
        .when(configuration: .debug)
    )
]

let swiftSettings: [SwiftSetting] = strictConcurrencySwiftSettings + actorDataRaceChecksSwiftSettings

let package = Package(
    name: "FolderBar",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "FolderBarCore",
            targets: ["FolderBarCore"]
        ),
        .library(
            name: "FolderBarApp",
            targets: ["FolderBarApp"]
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
            name: "FolderBarCore",
            swiftSettings: swiftSettings
        ),
        .target(
            name: "FolderBarApp",
            dependencies: [
                "FolderBarCore",
                .product(name: "Sparkle", package: "Sparkle")
            ],
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "FolderBar",
            dependencies: [
                "FolderBarApp"
            ],
            swiftSettings: swiftSettings,
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])
            ]
        ),
        .testTarget(
            name: "FolderBarTests",
            dependencies: ["FolderBarCore"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "FolderBarAppTests",
            dependencies: ["FolderBarApp"],
            swiftSettings: swiftSettings
        )
    ]
)
