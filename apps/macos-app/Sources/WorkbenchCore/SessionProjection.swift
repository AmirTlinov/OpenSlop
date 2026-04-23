import Foundation

public struct DaemonSessionProjection: Codable, Equatable, Sendable {
    public let kind: String
    public let sessions: [DaemonSessionSummary]

    public init(kind: String, sessions: [DaemonSessionSummary]) {
        self.kind = kind
        self.sessions = sessions
    }
}

public struct DaemonSessionSummary: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let workspace: String
    public let branch: String
    public let provider: String
    public let status: String

    public init(id: String, title: String, workspace: String, branch: String, provider: String, status: String) {
        self.id = id
        self.title = title
        self.workspace = workspace
        self.branch = branch
        self.provider = provider
        self.status = status
    }
}

struct CoreDaemonRequest: Codable, Sendable {
    let operation: String
    let sessionId: String?
    let inputText: String?

    init(operation: String, sessionId: String? = nil, inputText: String? = nil) {
        self.operation = operation
        self.sessionId = sessionId
        self.inputText = inputText
    }
}

struct CoreDaemonErrorResponse: Codable, Sendable {
    let kind: String
    let message: String
}
