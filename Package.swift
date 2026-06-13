// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NiceTextEditor",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "NiceTextEditor", targets: ["NiceTextEditor"])
    ],
    targets: [
        .executableTarget(
            name: "NiceTextEditor",
            path: "Sources/NiceTextEditor"
        )
    ]
)
