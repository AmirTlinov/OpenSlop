import Foundation

public struct DaemonClaudeRuntimeStatus: Codable, Equatable, Sendable {
    public let kind: String
    public let runtime: String
    public let available: Bool
    public let bridge: DaemonClaudeBridgeSummary
    public let binaryPath: String?
    public let cliVersion: String?
    public let nodeVersion: String?
    public let checkedAt: String
    public let capabilities: DaemonClaudeCapabilitySnapshot
    public let helpSignals: [String]
    public let warnings: [String]

    public var availabilityLabel: String {
        available ? "available" : "unavailable"
    }

    public var versionLabel: String {
        cliVersion ?? "version unknown"
    }

    public var boundaryLabel: String {
        available
            ? "Claude Code найден. S05b probe-only turn receipt доступен; GUI chat ещё закрыт."
            : "Claude runtime недоступен. GUI обязан держать этот путь fail-closed."
    }
}

public struct DaemonClaudeBridgeSummary: Codable, Equatable, Sendable {
    public let name: String
    public let version: String
    public let transport: String
}

public struct DaemonClaudeCapabilitySnapshot: Codable, Equatable, Sendable {
    public let runtimeDiscovery: Bool
    public let cliPrintJson: Bool
    public let cliStreamJsonOutput: Bool
    public let cliStreamJsonInput: Bool
    public let cliSessionResume: Bool
    public let cliExplicitSessionId: Bool
    public let cliPermissionMode: Bool
    public let cliMcpConfig: Bool
    public let bridgeTurnStreaming: Bool
    public let bridgeSessionMirror: Bool
    public let bridgeNativeApprovals: Bool
    public let bridgeTracingHandoff: Bool
}
