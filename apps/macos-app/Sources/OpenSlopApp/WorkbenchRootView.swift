import SwiftUI
import WorkbenchCore

private enum SessionProjectionLoadState {
    case idle
    case loading
    case loaded(kind: String, transport: String)
    case failed(message: String)

    var summary: String {
        switch self {
        case .idle:
            return "Projection ещё не загружена."
        case .loading:
            return "Загружаем session list через long-lived stdio transport."
        case .loaded(let kind, let transport):
            return "Daemon вернул projection kind=\(kind) через \(transport)."
        case .failed(let message):
            return message
        }
    }
}

struct WorkbenchRootView: View {
    private let seed = WorkbenchSeed.bootstrap
    private let client = CoreDaemonClient()

    @State private var sessions: [DaemonSessionSummary] = []
    @State private var selectedSessionID: DaemonSessionSummary.ID?
    @State private var promptText = "Поднять long-lived stdio IPC path"
    @State private var selectedProvider = "Codex"
    @State private var selectedEffort = "High"
    @State private var loadState: SessionProjectionLoadState = .idle

    private var selectedSession: DaemonSessionSummary? {
        sessions.first(where: { $0.id == selectedSessionID }) ?? sessions.first
    }

    private var projectionKind: String {
        if case .loaded(let kind, _) = loadState {
            return kind
        }
        return "session_list.pending"
    }

    var body: some View {
        NavigationSplitView {
            SidebarPanelView(
                sessions: sessions,
                selectedSessionID: $selectedSessionID,
                loadSummary: loadState.summary
            )
        } detail: {
            VStack(spacing: 0) {
                HSplitView {
                    TimelinePanelView(
                        session: selectedSession,
                        loadSummary: loadState.summary,
                        timeline: seed.timeline(
                            for: selectedSession,
                            loadSummary: loadState.summary
                        )
                    )
                    .frame(minWidth: 720)

                    InspectorPanelView(
                        cards: seed.inspectorCards(
                            projectionKind: projectionKind,
                            sessionsCount: sessions.count,
                            selectedSession: selectedSession
                        )
                    )
                    .frame(minWidth: 280, idealWidth: 320, maxWidth: 360)
                }

                Divider()

                ComposerBarView(
                    promptText: $promptText,
                    selectedProvider: $selectedProvider,
                    selectedEffort: $selectedEffort
                )
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Picker("Provider", selection: $selectedProvider) {
                        Text("Codex").tag("Codex")
                        Text("Claude").tag("Claude")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)

                    Button("Обновить") {
                        Task { await loadSessions(force: true) }
                    }
                    Button("Запустить") { }
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .task {
            await loadSessions(force: false)
        }
    }

    @MainActor
    private func loadSessions(force: Bool) async {
        if !force, case .loaded = loadState {
            return
        }

        loadState = .loading

        do {
            let projection = try await client.fetchSessionProjection()
            let daemonPID = try await client.daemonProcessIdentifier()
            sessions = projection.sessions
            selectedSessionID = selectedSessionID ?? projection.sessions.first?.id
            loadState = .loaded(kind: projection.kind, transport: "stdio pid=\(daemonPID)")
        } catch {
            sessions = []
            selectedSessionID = nil
            loadState = .failed(message: error.localizedDescription)
        }
    }
}
