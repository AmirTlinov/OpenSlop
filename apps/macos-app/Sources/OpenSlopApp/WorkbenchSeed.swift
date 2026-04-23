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
        loadSummary: String
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
                title: "core-daemon --query session-list",
                detail: "Sidebar и header больше не зависят от hardcoded списка."
            ),
            TimelineItemSeed(
                id: UUID(),
                kind: .verify,
                title: "S02 first proof target",
                detail: session.map { "Выбрана реальная session: \($0.title) [\($0.provider)]" } ?? "Ожидаем или не можем получить session list."
            ),
        ]
    }

    func inspectorCards(
        projectionKind: String,
        sessionsCount: Int,
        selectedSession: DaemonSessionSummary?
    ) -> [InspectorCardSeed] {
        [
            InspectorCardSeed(id: UUID(), title: "Projection", value: projectionKind),
            InspectorCardSeed(id: UUID(), title: "Sessions", value: "\(sessionsCount)"),
            InspectorCardSeed(id: UUID(), title: "Provider", value: selectedSession?.provider ?? "—"),
            InspectorCardSeed(id: UUID(), title: "Branch", value: selectedSession?.branch ?? "—"),
        ]
    }
}
