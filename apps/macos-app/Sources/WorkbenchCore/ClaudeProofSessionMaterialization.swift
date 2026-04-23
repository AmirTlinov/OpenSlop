import Foundation

public struct DaemonClaudeProofSessionMaterialization: Codable, Equatable, Sendable {
    public let kind: String
    public let session: DaemonSessionSummary
    public let proof: DaemonClaudeTurnProofResult
}
