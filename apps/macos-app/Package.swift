// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpenSlopMacApp",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(name: "WorkbenchCore", targets: ["WorkbenchCore"]),
        .executable(name: "OpenSlopApp", targets: ["OpenSlopApp"]),
        .executable(name: "OpenSlopProbe", targets: ["OpenSlopProbe"]),
        .executable(name: "OpenSlopCodexProbe", targets: ["OpenSlopCodexProbe"]),
    ],
    targets: [
        .target(
            name: "WorkbenchCore",
            path: "Sources/WorkbenchCore"
        ),
        .executableTarget(
            name: "OpenSlopApp",
            dependencies: ["WorkbenchCore"],
            path: "Sources/OpenSlopApp"
        ),
        .executableTarget(
            name: "OpenSlopProbe",
            dependencies: ["WorkbenchCore"],
            path: "Sources/OpenSlopProbe"
        ),
        .executableTarget(
            name: "OpenSlopCodexProbe",
            dependencies: ["WorkbenchCore"],
            path: "Sources/OpenSlopCodexProbe"
        ),
    ]
)
