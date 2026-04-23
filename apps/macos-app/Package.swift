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
        .executable(name: "OpenSlopTerminalTailProbe", targets: ["OpenSlopTerminalTailProbe"]),
        .executable(name: "OpenSlopShellStateProbe", targets: ["OpenSlopShellStateProbe"]),
        .executable(name: "OpenSlopTimelineEmptyStateProbe", targets: ["OpenSlopTimelineEmptyStateProbe"]),
        .executable(name: "OpenSlopCommandExecProbe", targets: ["OpenSlopCommandExecProbe"]),
        .executable(name: "OpenSlopCommandExecControlProbe", targets: ["OpenSlopCommandExecControlProbe"]),
        .executable(name: "OpenSlopCommandExecControlSurfaceProbe", targets: ["OpenSlopCommandExecControlSurfaceProbe"]),
        .executable(name: "OpenSlopCommandExecControlNegativeProbe", targets: ["OpenSlopCommandExecControlNegativeProbe"]),
        .executable(name: "OpenSlopCommandExecControlTimeoutProbe", targets: ["OpenSlopCommandExecControlTimeoutProbe"]),
        .executable(name: "OpenSlopCommandExecInteractiveProbe", targets: ["OpenSlopCommandExecInteractiveProbe"]),
        .executable(name: "OpenSlopCommandExecResizeProbe", targets: ["OpenSlopCommandExecResizeProbe"]),
        .executable(name: "OpenSlopCommandExecResizeSurfaceProbe", targets: ["OpenSlopCommandExecResizeSurfaceProbe"]),
        .executable(name: "OpenSlopGitReviewProbe", targets: ["OpenSlopGitReviewProbe"]),
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
            name: "OpenSlopTerminalTailProbe",
            dependencies: ["WorkbenchCore"],
            path: "Sources/OpenSlopTerminalTailProbe"
        ),
        .executableTarget(
            name: "OpenSlopShellStateProbe",
            dependencies: ["WorkbenchCore"],
            path: "Sources/OpenSlopShellStateProbe"
        ),
        .executableTarget(
            name: "OpenSlopTimelineEmptyStateProbe",
            dependencies: ["WorkbenchCore"],
            path: "Sources/OpenSlopTimelineEmptyStateProbe"
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
            name: "OpenSlopCommandExecControlSurfaceProbe",
            dependencies: ["WorkbenchCore"],
            path: "Sources/OpenSlopCommandExecControlSurfaceProbe"
        ),
        .executableTarget(
            name: "OpenSlopCommandExecControlNegativeProbe",
            dependencies: ["WorkbenchCore"],
            path: "Sources/OpenSlopCommandExecControlNegativeProbe"
        ),
        .executableTarget(
            name: "OpenSlopCommandExecControlTimeoutProbe",
            dependencies: ["WorkbenchCore"],
            path: "Sources/OpenSlopCommandExecControlTimeoutProbe"
        ),
        .executableTarget(
            name: "OpenSlopCommandExecInteractiveProbe",
            dependencies: ["WorkbenchCore"],
            path: "Sources/OpenSlopCommandExecInteractiveProbe"
        ),
        .executableTarget(
            name: "OpenSlopCommandExecResizeProbe",
            dependencies: ["WorkbenchCore"],
            path: "Sources/OpenSlopCommandExecResizeProbe"
        ),
        .executableTarget(
            name: "OpenSlopCommandExecResizeSurfaceProbe",
            dependencies: ["WorkbenchCore"],
            path: "Sources/OpenSlopCommandExecResizeSurfaceProbe"
        ),
        .executableTarget(
            name: "OpenSlopGitReviewProbe",
            dependencies: ["WorkbenchCore"],
            path: "Sources/OpenSlopGitReviewProbe"
        ),
    ]
)
