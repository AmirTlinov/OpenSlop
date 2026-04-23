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
    let approvalId: String?
    let approvalDecision: String?
    let command: [String]?
    let cwd: String?
    let processId: String?
    let streamStdoutStderr: Bool?
    let tty: Bool?
    let cols: Int?
    let rows: Int?
    let deltaBase64: String?
    let closeStdin: Bool?

    init(
        operation: String,
        sessionId: String? = nil,
        inputText: String? = nil,
        approvalId: String? = nil,
        approvalDecision: String? = nil,
        command: [String]? = nil,
        cwd: String? = nil,
        processId: String? = nil,
        streamStdoutStderr: Bool? = nil,
        tty: Bool? = nil,
        cols: Int? = nil,
        rows: Int? = nil,
        deltaBase64: String? = nil,
        closeStdin: Bool? = nil
    ) {
        self.operation = operation
        self.sessionId = sessionId
        self.inputText = inputText
        self.approvalId = approvalId
        self.approvalDecision = approvalDecision
        self.command = command
        self.cwd = cwd
        self.processId = processId
        self.streamStdoutStderr = streamStdoutStderr
        self.tty = tty
        self.cols = cols
        self.rows = rows
        self.deltaBase64 = deltaBase64
        self.closeStdin = closeStdin
    }
}

struct CoreDaemonErrorResponse: Codable, Sendable {
    let kind: String
    let message: String
}
