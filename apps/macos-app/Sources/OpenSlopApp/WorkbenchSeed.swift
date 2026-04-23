import Foundation
import WorkbenchCore

struct TimelineItemSeed: Identifiable, Hashable {
    enum Kind: String {
        case user = "User"
        case agent = "Agent"
        case tool = "Tool"
        case verify = "Verify"
    }

    let id: String
    let kind: Kind
    let title: String
    let detail: String
}

struct InspectorCardSeed: Identifiable, Hashable {
    let id: String
    let title: String
    let value: String
}

struct WorkbenchSeed {
    static let bootstrap = WorkbenchSeed()

    func timeline(
        for session: DaemonSessionSummary?,
        loadSummary: String,
        transcriptSummary: String,
        transcript: DaemonCodexTranscript?
    ) -> [TimelineItemSeed] {
        if let transcript, !transcript.items.isEmpty {
            return transcript.items.map { item in
                TimelineItemSeed(
                    id: item.id,
                    kind: timelineKind(for: item.kind),
                    title: item.title,
                    detail: item.text.isEmpty ? item.turnStatus : item.text
                )
            }
        }

        return [
            TimelineItemSeed(
                id: "projection",
                kind: .agent,
                title: "Session projection loaded from daemon",
                detail: loadSummary
            ),
            TimelineItemSeed(
                id: "transcript",
                kind: .tool,
                title: "Read-only transcript lane",
                detail: transcriptSummary
            ),
            TimelineItemSeed(
                id: "proof-target",
                kind: .verify,
                title: "S04 first proof target",
                detail: session.map { "Выбрана session: \($0.title) [\($0.provider)]" } ?? "Ожидаем или не можем получить session list."
            ),
        ]
    }

    func inspectorCards(
        projectionKind: String,
        sessionsCount: Int,
        selectedSession: DaemonSessionSummary?,
        transcript: DaemonCodexTranscript?
    ) -> [InspectorCardSeed] {
        [
            InspectorCardSeed(id: "projection", title: "Projection", value: projectionKind),
            InspectorCardSeed(id: "sessions", title: "Sessions", value: "\(sessionsCount)"),
            InspectorCardSeed(id: "provider", title: "Provider", value: selectedSession?.provider ?? "—"),
            InspectorCardSeed(id: "branch", title: "Branch", value: selectedSession?.branch ?? "—"),
            InspectorCardSeed(id: "thread", title: "Thread", value: transcript?.threadId ?? selectedSession?.id ?? "—"),
            InspectorCardSeed(id: "turns", title: "Turns", value: transcript.map { "\($0.turnCount)" } ?? "0"),
            InspectorCardSeed(id: "last-turn", title: "Last turn", value: transcript?.lastTurnStatus ?? "—"),
        ]
    }

    private func timelineKind(for rawKind: String) -> TimelineItemSeed.Kind {
        switch rawKind {
        case "user":
            return .user
        case "agent":
            return .agent
        case "tool":
            return .tool
        default:
            return .verify
        }
    }
}
