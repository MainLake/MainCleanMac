// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MainCleanMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MainCleanMac", targets: ["MainCleanMac"])
    ],
    targets: [
        .executableTarget(
            name: "MainCleanMac",
            path: "Sources/MainCleanMac"
        ),
        .testTarget(
            name: "MainCleanMacTests",
            dependencies: ["MainCleanMac"],
            path: "Tests/MainCleanMacTests"
        )
    ]
)
