import Foundation

public struct DaemonCodexApprovalRequest: Codable, Equatable, Identifiable, Sendable {
    public let kind: String
    public let approvalId: String
    public let threadId: String
    public let turnId: String
    public let itemId: String
    public let command: String?
    public let cwd: String?
    public let reason: String?
    public let grantRoot: String?

    public var id: String { approvalId }
}

public enum DaemonCodexApprovalDecision: String, Codable, Equatable, Sendable {
    case accept
    case cancel
}

public struct DaemonCodexApprovalRequestEvent: Codable, Equatable, Sendable {
    public let kind: String
    public let sessionId: String
    public let approval: DaemonCodexApprovalRequest
}
