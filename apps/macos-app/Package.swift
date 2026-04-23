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
        .executable(name: "OpenSlopApprovalProbe", targets: ["OpenSlopApprovalProbe"]),
        .executable(name: "OpenSlopTurnProbe", targets: ["OpenSlopTurnProbe"]),
        .executable(name: "OpenSlopTerminalInteractionProbe", targets: ["OpenSlopTerminalInteractionProbe"]),
        .executable(name: "OpenSlopTerminalSurfaceProbe", targets: ["OpenSlopTerminalSurfaceProbe"]),
        .executable(name: "OpenSlopCommandExecProbe", targets: ["OpenSlopCommandExecProbe"]),
        .executable(name: "OpenSlopCommandExecControlProbe", targets: ["OpenSlopCommandExecControlProbe"]),
        .executable(name: "OpenSlopCommandExecControlNegativeProbe", targets: ["OpenSlopCommandExecControlNegativeProbe"]),
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
        .executableTarget(
            name: "OpenSlopApprovalProbe",
            dependencies: ["WorkbenchCore"],
            path: "Sources/OpenSlopApprovalProbe"
        ),
        .executableTarget(
            name: "OpenSlopTurnProbe",
            dependencies: ["WorkbenchCore"],
            path: "Sources/OpenSlopTurnProbe"
        ),
        .executableTarget(
            name: "OpenSlopTerminalInteractionProbe",
            dependencies: ["WorkbenchCore"],
            path: "Sources/OpenSlopTerminalInteractionProbe"
        ),
        .executableTarget(
            name: "OpenSlopTerminalSurfaceProbe",
            dependencies: ["WorkbenchCore"],
            path: "Sources/OpenSlopTerminalSurfaceProbe"
        ),
        .executableTarget(
            name: "OpenSlopCommandExecProbe",
            dependencies: ["WorkbenchCore"],
            path: "Sources/OpenSlopCommandExecProbe"
        ),
        .executableTarget(
            name: "OpenSlopCommandExecControlProbe",
            dependencies: ["WorkbenchCore"],
            path: "Sources/OpenSlopCommandExecControlProbe"
        ),
        .executableTarget(
            name: "OpenSlopCommandExecControlNegativeProbe",
            dependencies: ["WorkbenchCore"],
            path: "Sources/OpenSlopCommandExecControlNegativeProbe"
        ),
    ]
)
