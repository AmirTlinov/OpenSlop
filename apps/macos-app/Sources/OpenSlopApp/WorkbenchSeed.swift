import Foundation
import WorkbenchCore

struct TimelineItemSeed: Identifiable, Hashable {
    enum Kind: String {
        case user = "User"
        case agent = "Agent"
        case tool = "Tool"
        case verify = "Verify"
    }

    let id: UUID
    let kind: Kind
    let title: String
    let detail: String
}

struct InspectorCardSeed: Identifiable, Hashable {
    let id: UUID
    let title: String
    let value: String
}

struct WorkbenchSeed {
    static let bootstrap = WorkbenchSeed()

    func timeline(
        for session: DaemonSessionSummary?,
        loadSummary: String,
        bootstrapSummary: String
    ) -> [TimelineItemSeed] {
        [
            TimelineItemSeed(
                id: UUID(),
                kind: .agent,
                title: "Session projection loaded from daemon",
                detail: loadSummary
            ),
            TimelineItemSeed(
                id: UUID(),
                kind: .tool,
                title: "core-daemon -> codex app-server -> thread/start",
                detail: bootstrapSummary
            ),
            TimelineItemSeed(
                id: UUID(),
                kind: .verify,
                title: "S03 first proof target",
                detail: session.map { "Выбрана materialized session: \($0.title) [\($0.provider)]" } ?? "Ожидаем или не можем получить session list."
            ),
        ]
    }

    func inspectorCards(
        projectionKind: String,
        sessionsCount: Int,
        selectedSession: DaemonSessionSummary?,
        lastBootstrap: DaemonCodexSessionBootstrap?
    ) -> [InspectorCardSeed] {
        [
            InspectorCardSeed(id: UUID(), title: "Projection", value: projectionKind),
            InspectorCardSeed(id: UUID(), title: "Sessions", value: "\(sessionsCount)"),
            InspectorCardSeed(id: UUID(), title: "Provider", value: selectedSession?.provider ?? "—"),
            InspectorCardSeed(id: UUID(), title: "Branch", value: selectedSession?.branch ?? "—"),
            InspectorCardSeed(id: UUID(), title: "Codex model", value: lastBootstrap?.model ?? "ещё не запускали"),
            InspectorCardSeed(id: UUID(), title: "Thread", value: lastBootstrap?.providerThreadId ?? "—"),
            InspectorCardSeed(id: UUID(), title: "CLI", value: lastBootstrap?.cliVersion ?? "—"),
        ]
    }
}
