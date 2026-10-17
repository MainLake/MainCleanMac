// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RamanSweep",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "RamanSweep", targets: ["RamanSweep"])
    ],
    targets: [
        .executableTarget(
            name: "RamanSweep",
            path: "Sources/RamanSweep"
        )
    ]
)
