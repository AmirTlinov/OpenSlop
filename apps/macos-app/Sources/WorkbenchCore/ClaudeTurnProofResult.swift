import Foundation

public struct DaemonClaudeTurnProofResult: Codable, Equatable, Sendable {
    public let kind: String
    public let runtime: String
    public let success: Bool
    public let runtimeAvailable: Bool
    public let bridge: DaemonClaudeBridgeSummary
    public let model: String?
    public let sessionId: String?
    public let resultText: String
    public let assistantText: String
    public let eventCount: Int
    public let eventTypes: [String]
    public let toolUseCount: Int
    public let malformedEventCount: Int
    public let sessionPersistence: String
    public let totalCostUsd: Double?
    public let durationMs: UInt64?
    public let exitCode: Int?
    public let signal: String?
    public let timedOut: Bool
    public let promptBytes: Int
    public let warnings: [String]

    public var proofLabel: String {
        success ? "real Claude turn proven" : "Claude turn proof failed closed"
    }
}
