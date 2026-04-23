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

private enum TranscriptState {
    case idle
    case loading
    case loaded(summary: String)
    case streaming(summary: String)
    case awaitingApproval(summary: String)
    case submitting
    case unavailable(message: String)
    case failed(message: String)

    var summary: String {
        switch self {
        case .idle:
            return "Transcript ещё не загружен."
        case .loading:
            return "Читаем transcript snapshot из core-daemon."
        case .loaded(let summary):
            return summary
        case .streaming(let summary):
            return summary
        case .awaitingApproval(let summary):
            return summary
        case .submitting:
            return "Запускаем live turn и ждём первые streaming snapshot’ы."
        case .unavailable(let message):
            return message
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
    @State private var promptText = "Reply with exactly OK."
    @State private var selectedProvider = "Codex"
    @State private var selectedEffort = "High"
    @State private var loadState: SessionProjectionLoadState = .idle
    @State private var codexBootstrapState: CodexBootstrapState = .idle
    @State private var transcriptState: TranscriptState = .idle
    @State private var lastBootstrap: DaemonCodexSessionBootstrap?
    @State private var transcript: DaemonCodexTranscript?
    @State private var pendingApproval: DaemonCodexApprovalRequest?
    @State private var approvalContinuation: CheckedContinuation<DaemonCodexApprovalDecision, Never>?

    private var selectedSession: DaemonSessionSummary? {
        sessions.first(where: { $0.id == selectedSessionID }) ?? sessions.first
    }

    private var projectionKind: String {
        if case .loaded(let kind, _) = loadState {
            return kind
        }
        return "session_list.pending"
    }

    private var canSubmitTurn: Bool {
        guard selectedProvider == "Codex", let selectedSession else {
            return false
        }
        return !isTurnStreaming
            && looksLikeLiveCodexThread(selectedSession.id)
            && !promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isTurnStreaming: Bool {
        switch transcriptState {
        case .submitting, .streaming, .awaitingApproval:
            return true
        default:
            return false
        }
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
                        transcriptSummary: transcriptState.summary,
                        timeline: seed.timeline(
                            for: selectedSession,
                            loadSummary: loadState.summary,
                            transcriptSummary: transcriptState.summary,
                            transcript: transcript,
                            pendingApproval: pendingApproval
                        )
                    )
                    .frame(minWidth: 720)

                    InspectorPanelView(
                        cards: seed.inspectorCards(
                            projectionKind: projectionKind,
                            sessionsCount: sessions.count,
                            selectedSession: selectedSession,
                            transcript: transcript,
                            pendingApproval: pendingApproval
                        )
                    )
                    .frame(minWidth: 280, idealWidth: 320, maxWidth: 360)
                }

                Divider()

                ComposerBarView(
                    promptText: $promptText,
                    selectedProvider: $selectedProvider,
                    selectedEffort: $selectedEffort,
                    onSubmit: {
                        Task { await submitTurn() }
                    },
                    isSubmitDisabled: !canSubmitTurn
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
                        Task { await loadSessions(force: true, preferredSessionID: selectedSessionID) }
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
        .task(id: selectedSessionID) {
            await loadTranscriptForSelection(force: true)
        }
        .sheet(item: $pendingApproval) { approval in
            ApprovalSheetView(
                approval: approval,
                onApprove: { resolvePendingApproval(.accept) },
                onDeny: { resolvePendingApproval(.cancel) }
            )
            .interactiveDismissDisabled(true)
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
            selectedSessionID = preferredSessionID ?? preferredSession(in: projection.sessions) ?? projection.sessions.first?.id
            loadState = .loaded(kind: projection.kind, transport: "stdio pid=\(daemonPID)")
        } catch {
            sessions = []
            selectedSessionID = nil
            transcript = nil
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
            transcript = nil
            transcriptState = .unavailable(message: "Live session создана. Теперь можно отправить первый turn.")
        } catch {
            codexBootstrapState = .failed(message: error.localizedDescription)
        }
    }

    @MainActor
    private func loadTranscriptForSelection(force: Bool) async {
        guard let selectedSession else {
            transcript = nil
            transcriptState = .idle
            return
        }

        guard looksLikeLiveCodexThread(selectedSession.id) else {
            transcript = nil
            transcriptState = .unavailable(message: "Эта session seeded. Нажми Запустить, чтобы создать живую Codex session.")
            return
        }

        if !force, transcript?.threadId == selectedSession.id {
            return
        }

        transcriptState = .loading

        do {
            let snapshot = try await client.fetchCodexTranscript(sessionId: selectedSession.id)
            transcript = snapshot
            transcriptState = snapshot.items.isEmpty
                ? .unavailable(message: "У этой session пока нет transcript. Отправь первый turn.")
                : .loaded(summary: transcriptSummary(for: snapshot))
        } catch {
            transcript = nil
            transcriptState = transcriptUnavailableState(for: error)
        }
    }

    @MainActor
    private func submitTurn() async {
        guard let selectedSession else {
            transcriptState = .unavailable(message: "Сначала выбери или создай живую Codex session.")
            return
        }

        let input = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            transcriptState = .unavailable(message: "Пустой turn отправлять нельзя.")
            return
        }

        transcriptState = .submitting

        do {
            let snapshot = try await client.streamCodexTurn(
                sessionId: selectedSession.id,
                inputText: input
            ) { streamedSnapshot in
                await MainActor.run {
                    transcript = streamedSnapshot
                    transcriptState = .streaming(summary: transcriptSummary(for: streamedSnapshot))
                }
            } onApprovalRequest: { approval in
                await MainActor.run {
                    transcriptState = .awaitingApproval(summary: approvalSummary(for: approval))
                }
                return await awaitApprovalDecision(for: approval)
            }
            transcript = snapshot
            pendingApproval = nil
            transcriptState = .loaded(summary: transcriptSummary(for: snapshot))
            await loadSessions(force: true, preferredSessionID: selectedSession.id)
        } catch {
            pendingApproval = nil
            transcriptState = transcriptUnavailableState(for: error)
        }
    }

    private func preferredSession(in sessions: [DaemonSessionSummary]) -> String? {
        sessions.last(where: { looksLikeLiveCodexThread($0.id) })?.id
    }

    private func looksLikeLiveCodexThread(_ value: String) -> Bool {
        value.count == 36 && value.filter({ $0 == "-" }).count >= 4
    }

    private func transcriptSummary(for snapshot: DaemonCodexTranscript) -> String {
        let agentCount = snapshot.items.filter { $0.kind == "agent" }.count
        let commandCount = snapshot.items.filter { $0.kind == "command" }.count
        let fileChangeCount = snapshot.items.filter { $0.kind == "fileChange" }.count
        let toolCount = snapshot.items.filter { $0.kind == "tool" }.count
        return "thread=\(snapshot.threadId) status=\(snapshot.threadStatus) turns=\(snapshot.turnCount) last=\(snapshot.lastTurnStatus ?? "—") agent=\(agentCount) command=\(commandCount) files=\(fileChangeCount) tool=\(toolCount)"
    }

    @MainActor
    private func awaitApprovalDecision(for approval: DaemonCodexApprovalRequest) async -> DaemonCodexApprovalDecision {
        pendingApproval = approval
        return await withCheckedContinuation { continuation in
            approvalContinuation = continuation
        }
    }

    @MainActor
    private func resolvePendingApproval(_ decision: DaemonCodexApprovalDecision) {
        let continuation = approvalContinuation
        approvalContinuation = nil
        pendingApproval = nil
        transcriptState = .streaming(summary: decision == .accept ? "Approval отправлен. Ждём продолжение turn." : "Approval отклонён. Ждём terminal snapshot.")
        continuation?.resume(returning: decision)
    }

    private func approvalSummary(for approval: DaemonCodexApprovalRequest) -> String {
        switch approval.kind {
        case "commandExecution":
            return "Codex ждёт approve/deny для команды: \(approval.command ?? approval.itemId)"
        case "fileChange":
            return "Codex ждёт approve/deny для изменения файлов: \(approval.grantRoot ?? approval.reason ?? approval.itemId)"
        default:
            return "Codex ждёт approve/deny для действия: \(approval.itemId)"
        }
    }

    private func transcriptUnavailableState(for error: Error) -> TranscriptState {
        let message = error.localizedDescription
        if message.contains("первый turn нужно завершить в том же живом daemon runtime") {
            return .unavailable(message: "Эта session пережила перезапуск раньше первого ответа. Первый turn ещё не materialized на диск, поэтому восстановить её уже нельзя.")
        }
        return .failed(message: message)
    }
}
