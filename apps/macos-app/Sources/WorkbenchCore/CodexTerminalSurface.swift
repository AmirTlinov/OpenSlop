import Foundation

public struct DaemonCodexTerminalSurface: Equatable, Sendable {
    public let itemId: String
    public let title: String
    public let command: String
    public let processId: String
    public let output: String
    public let terminalStdin: String
    public let exitCode: Int?
    public let turnStatus: String

    public init(
        itemId: String,
        title: String,
        command: String,
        processId: String,
        output: String,
        terminalStdin: String,
        exitCode: Int?,
        turnStatus: String
    ) {
        self.itemId = itemId
        self.title = title
        self.command = command
        self.processId = processId
        self.output = output
        self.terminalStdin = terminalStdin
        self.exitCode = exitCode
        self.turnStatus = turnStatus
    }
}

public enum DaemonCodexTerminalSurfaceProjector {
    public static func liveSurface(from transcript: DaemonCodexTranscript?) -> DaemonCodexTerminalSurface? {
        guard let transcript else {
            return nil
        }

        guard let item = transcript.items.reversed().first(where: isLiveTerminalCandidate) else {
            return nil
        }

        return DaemonCodexTerminalSurface(
            itemId: item.id,
            title: item.title,
            command: item.command ?? item.title,
            processId: item.processId ?? "",
            output: item.text,
            terminalStdin: item.terminalStdin ?? "",
            exitCode: item.exitCode,
            turnStatus: item.turnStatus
        )
    }

    private static func isLiveTerminalCandidate(_ item: DaemonCodexTranscriptItem) -> Bool {
        guard item.kind == "command" else {
            return false
        }

        guard let processId = item.processId, !processId.isEmpty else {
            return false
        }

        guard let terminalStdin = item.terminalStdin, !terminalStdin.isEmpty else {
            return false
        }

        return true
    }
}
