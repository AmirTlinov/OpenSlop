import Foundation

public struct DaemonCodexTranscript: Codable, Equatable, Sendable {
    public let kind: String
    public let threadId: String
    public let preview: String
    public let threadStatus: String
    public let turnCount: Int
    public let lastTurnStatus: String?
    public let items: [DaemonCodexTranscriptItem]

    public init(
        kind: String,
        threadId: String,
        preview: String,
        threadStatus: String,
        turnCount: Int,
        lastTurnStatus: String?,
        items: [DaemonCodexTranscriptItem]
    ) {
        self.kind = kind
        self.threadId = threadId
        self.preview = preview
        self.threadStatus = threadStatus
        self.turnCount = turnCount
        self.lastTurnStatus = lastTurnStatus
        self.items = items
    }
}

public struct DaemonCodexTranscriptItem: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let turnId: String
    public let kind: String
    public let title: String
    public let text: String
    public let turnStatus: String
    public let command: String?
    public let processId: String?
    public let exitCode: Int?
    public let terminalStdin: String?

    public init(
        id: String,
        turnId: String,
        kind: String,
        title: String,
        text: String,
        turnStatus: String,
        command: String?,
        processId: String?,
        exitCode: Int?,
        terminalStdin: String?
    ) {
        self.id = id
        self.turnId = turnId
        self.kind = kind
        self.title = title
        self.text = text
        self.turnStatus = turnStatus
        self.command = command
        self.processId = processId
        self.exitCode = exitCode
        self.terminalStdin = terminalStdin
    }
}

public struct DaemonCodexTranscriptStreamEvent: Codable, Equatable, Sendable {
    public let kind: String
    public let sessionId: String
    public let snapshot: DaemonCodexTranscript
}
