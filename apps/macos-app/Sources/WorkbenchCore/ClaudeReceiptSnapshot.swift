import Foundation

public struct DaemonClaudeReceiptSnapshot: Codable, Equatable, Sendable {
    public let kind: String
    public let session: DaemonSessionSummary
    public let proof: DaemonClaudeTurnProofResult
    public let promptPolicy: DaemonClaudeReceiptPromptPolicySnapshot
    public let storagePath: String
    public let lifecycleBoundary: String
}

public struct DaemonClaudeReceiptPromptPolicySnapshot: Codable, Equatable, Sendable {
    public let maxBytes: Int
    public let promptBytes: Int
    public let bounded: Bool
}
