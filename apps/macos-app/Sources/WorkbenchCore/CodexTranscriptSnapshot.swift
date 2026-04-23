import Foundation

public struct DaemonCodexTranscript: Codable, Equatable, Sendable {
    public let kind: String
    public let threadId: String
    public let preview: String
    public let threadStatus: String
    public let turnCount: Int
    public let lastTurnStatus: String?
    public let items: [DaemonCodexTranscriptItem]
}

public struct DaemonCodexTranscriptItem: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let turnId: String
    public let kind: String
    public let title: String
    public let text: String
    public let turnStatus: String
}
