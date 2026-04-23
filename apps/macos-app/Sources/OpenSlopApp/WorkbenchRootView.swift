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

private enum CodexBootstrapState {
    case idle
    case running
    case completed(summary: String)
    case failed(message: String)

    var summary: String {
        switch self {
        case .idle:
            return "Codex thread ещё не запускали из GUI."
        case .running:
            return "core-daemon поднимает codex app-server и стартует real thread."
        case .completed(let summary):
            return summary
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
    @State private var promptText = "Materialize first real Codex thread"
    @State private var selectedProvider = "Codex"
    @State private var selectedEffort = "High"
    @State private var loadState: SessionProjectionLoadState = .idle
    @State private var codexBootstrapState: CodexBootstrapState = .idle
    @State private var lastBootstrap: DaemonCodexSessionBootstrap?

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
                            loadSummary: loadState.summary,
                            bootstrapSummary: codexBootstrapState.summary
                        )
                    )
                    .frame(minWidth: 720)

                    InspectorPanelView(
                        cards: seed.inspectorCards(
                            projectionKind: projectionKind,
                            sessionsCount: sessions.count,
                            selectedSession: selectedSession,
                            lastBootstrap: lastBootstrap
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
                        Task { await loadSessions(force: true, preferredSessionID: nil) }
                    }
                    Button("Запустить") {
                        Task { await startCodexSession() }
                    }
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .task {
            await loadSessions(force: false, preferredSessionID: nil)
        }
    }

    @MainActor
    private func loadSessions(force: Bool, preferredSessionID: String?) async {
        if !force, case .loaded = loadState {
            return
        }

        loadState = .loading

        do {
            let projection = try await client.fetchSessionProjection()
            let daemonPID = try await client.daemonProcessIdentifier()
            sessions = projection.sessions
            selectedSessionID = preferredSessionID ?? selectedSessionID ?? projection.sessions.first?.id
            loadState = .loaded(kind: projection.kind, transport: "stdio pid=\(daemonPID)")
        } catch {
            sessions = []
            selectedSessionID = nil
            loadState = .failed(message: error.localizedDescription)
        }
    }

    @MainActor
    private func startCodexSession() async {
        codexBootstrapState = .running

        do {
            let bootstrap = try await client.startCodexSession()
            lastBootstrap = bootstrap
            codexBootstrapState = .completed(
                summary: "Codex thread \(bootstrap.providerThreadId) materialized через \(bootstrap.transport), model=\(bootstrap.model), cli=\(bootstrap.cliVersion)."
            )
            await loadSessions(force: true, preferredSessionID: bootstrap.session.id)
        } catch {
            codexBootstrapState = .failed(message: error.localizedDescription)
        }
    }
}
