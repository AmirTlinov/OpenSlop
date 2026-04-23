import Foundation

struct ProjectSeed: Identifiable, Hashable {
    let id: UUID
    let name: String
    let branch: String
}

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
    let projects: [ProjectSeed]
    let timeline: [TimelineItemSeed]
    let inspectorCards: [InspectorCardSeed]

    static let preview = WorkbenchSeed(
        projects: [
            ProjectSeed(id: UUID(), name: "OpenSlop", branch: "main"),
            ProjectSeed(id: UUID(), name: "Main Cluster", branch: "feature/codex-runtime"),
            ProjectSeed(id: UUID(), name: "Sprite Studio", branch: "review/browser-pane"),
        ],
        timeline: [
            TimelineItemSeed(id: UUID(), kind: .user, title: "Собрать первый слайс", detail: "Создать репозиторную конституцию и минимальные seeds."),
            TimelineItemSeed(id: UUID(), kind: .agent, title: "Root документы готовы", detail: "AGENTS, PHILOSOPHY, ARCHITECTURE, DESIGN и ROADMAP материализованы."),
            TimelineItemSeed(id: UUID(), kind: .tool, title: "make doctor", detail: "Проверка формы репозитория и обязательных узлов."),
            TimelineItemSeed(id: UUID(), kind: .verify, title: "S00 acceptance", detail: "macOS shell seed, daemon heartbeat и repo-lint должны быть зелёными."),
        ],
        inspectorCards: [
            InspectorCardSeed(id: UUID(), title: "Provider", value: "Codex / Claude planned"),
            InspectorCardSeed(id: UUID(), title: "Verify", value: "S00 in progress"),
            InspectorCardSeed(id: UUID(), title: "Browser", value: "Preview domain planned"),
            InspectorCardSeed(id: UUID(), title: "Sessions", value: "3 sample entries"),
        ]
    )
}
