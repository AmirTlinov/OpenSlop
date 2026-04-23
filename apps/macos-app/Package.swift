// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpenSlopMacApp",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .executable(name: "OpenSlopApp", targets: ["OpenSlopApp"]),
    ],
    targets: [
        .executableTarget(
            name: "OpenSlopApp",
            path: "Sources/OpenSlopApp"
        ),
    ]
)
