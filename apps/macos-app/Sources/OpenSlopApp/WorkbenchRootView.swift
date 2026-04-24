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
        case let .loaded(kind, transport):
            return "Daemon вернул projection kind=\(kind) через \(transport)."
        case let .failed(message):
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
        case let .completed(summary):
            return summary
        case let .failed(message):
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
        case let .loaded(summary):
            return summary
        case let .streaming(summary):
            return summary
        case let .awaitingApproval(summary):
            return summary
        case .submitting:
            return "Запускаем live turn и ждём первые streaming snapshot’ы."
        case let .unavailable(message):
            return message
        case let .failed(message):
            return message
        }
    }
}

struct WorkbenchRootView: View {
    private let seed = WorkbenchSeed.bootstrap
    private let client = CoreDaemonClient()

    @State private var sessions: [DaemonSessionSummary] = []
    @State private var shellState: WorkbenchShellState
    @State private var promptText = ""
    @State private var claudeReceiptPromptText = DaemonClaudeReceiptPromptPolicy.defaultPrompt
    @State private var loadState: SessionProjectionLoadState = .idle
    @State private var codexBootstrapState: CodexBootstrapState = .idle
    @State private var transcriptState: TranscriptState = .idle
    @State private var lastBootstrap: DaemonCodexSessionBootstrap?
    @State private var transcript: DaemonCodexTranscript?
    @State private var pendingApproval: DaemonCodexApprovalRequest?
    @State private var approvalContinuation: CheckedContinuation<DaemonCodexApprovalDecision, Never>?
    @State private var commandExecProofMode: CommandExecProofMode = .interactiveStdin
    @State private var commandExecStdinText = DaemonCodexCommandExecProofCommand.defaultInteractiveInput
    @State private var commandExecSurface: DaemonCodexCommandExecControlSurface?
    @State private var gitReviewSnapshot: DaemonGitReviewSnapshot?
    @State private var gitReviewSelectedPath: String?
    @State private var gitReviewError: String?
    @State private var isGitReviewLoading = false
    @State private var claudeRuntimeStatus: DaemonClaudeRuntimeStatus?
    @State private var claudeRuntimeError: String?
    @State private var isClaudeRuntimeLoading = false
    @State private var executionProfileStatus: DaemonExecutionProfileStatus?
    @State private var executionProfileError: String?
    @State private var isExecutionProfileLoading = false
    @State private var isClaudeProofRunning = false
    @State private var claudeReceiptSnapshot: DaemonClaudeReceiptSnapshot?
    @State private var claudeReceiptError: String?
    @State private var inspectorTab: InspectorPanelTab = .plan
    @State private var commandExecContinuation: CheckedContinuation<DaemonCodexCommandExecControlRequest?, Never>?
    @State private var commandExecAllowsMoreControls = false
    @State private var commandExecResizeSent = false

    init(initialShellState: WorkbenchShellState = WorkbenchShellStateStore.load()) {
        _shellState = State(initialValue: initialShellState.sanitized())
    }

    private var selectedSession: DaemonSessionSummary? {
        sessions.first(where: { $0.id == shellState.selectedSessionID }) ?? sessions.first
    }

    private var currentTimelineEmptyState: WorkbenchTimelineEmptyState? {
        seed.timelineEmptyState(
            for: selectedSession,
            transcript: transcript
        )
    }

    private var shouldShowBottomComposer: Bool {
        currentTimelineEmptyState == nil && selectedSession?.provider != "Claude"
    }

    private var isCodexBootstrapRunning: Bool {
        if case .running = codexBootstrapState {
            return true
        }
        return false
    }

    private var canStartCodexSession: Bool {
        executionProfile(for: "Codex")?.isSubmitCapable == true
            && shellState.selectedProvider == "Codex"
            && !isCodexBootstrapRunning
    }

    private var canStartProviderSession: Bool {
        switch shellState.selectedProvider {
        case "Codex":
            return canStartCodexSession
        case "Claude":
            return executionProfile(for: "Claude")?.isReceiptCapable == true
                && !isClaudeProofRunning
                && claudeReceiptPromptValidationMessage == nil
        default:
            return false
        }
    }

    private var projectionKind: String {
        if case let .loaded(kind, _) = loadState {
            return kind
        }
        return "session_list.pending"
    }


    private var trimmedClaudeReceiptPrompt: String {
        DaemonClaudeReceiptPromptPolicy.trimmed(claudeReceiptPromptText)
    }

    private var claudeReceiptPromptValidationMessage: String? {
        DaemonClaudeReceiptPromptPolicy.validationMessage(for: claudeReceiptPromptText)
    }

    private var canSubmitTurn: Bool {
        guard shellState.selectedProvider == "Codex", let selectedSession else {
            return false
        }
        return executionProfile(for: "Codex")?.isSubmitCapable == true
            && !isTurnStreaming
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

    private func executionProfile(for provider: String) -> DaemonExecutionProviderProfile? {
        guard !isExecutionProfileLoading, executionProfileError == nil else {
            return nil
        }
        return executionProfileStatus?.profile(for: provider)
    }

    private var commandExecCommand: [String] {
        commandExecProofMode.command
    }

    private var canRunCommandExec: Bool {
        !commandExecCommand.isEmpty && !isCommandExecActive
    }

    private var isCommandExecActive: Bool {
        guard let commandExecSurface else {
            return false
        }

        switch commandExecSurface.stage {
        case .running, .awaitingControl:
            return true
        default:
            return false
        }
    }

    private var canSendCommandExecWrite: Bool {
        guard let commandExecSurface else {
            return false
        }

        return commandExecSurface.stage == .awaitingControl
            && commandExecContinuation != nil
            && commandExecAllowsMoreControls
            && commandExecProofMode == .interactiveStdin
    }

    private var canSendCommandExecResize: Bool {
        guard let commandExecSurface else {
            return false
        }

        return commandExecSurface.stage == .awaitingControl
            && commandExecContinuation != nil
            && commandExecAllowsMoreControls
            && commandExecProofMode == .ptyResize
            && !commandExecResizeSent
    }

    private var canSendCommandExecWriteAndClose: Bool {
        guard let commandExecSurface else {
            return false
        }

        return commandExecSurface.stage == .awaitingControl
            && commandExecContinuation != nil
            && commandExecAllowsMoreControls
            && commandExecProofMode == .ptyResize
            && commandExecResizeSent
    }

    private var canCloseCommandExecStdin: Bool {
        guard let commandExecSurface else {
            return false
        }

        return commandExecSurface.stage == .awaitingControl
            && commandExecContinuation != nil
            && commandExecAllowsMoreControls
            && commandExecProofMode == .interactiveStdin
    }

    private var canTerminateCommandExec: Bool {
        guard let commandExecSurface else {
            return false
        }

        return commandExecSurface.stage == .awaitingControl
            && commandExecContinuation != nil
            && commandExecAllowsMoreControls
            && commandExecProofMode == .interactiveStdin
    }

    var body: some View {
        NavigationSplitView {
            SidebarPanelView(
                sessions: sessions,
                selectedSessionID: $shellState.selectedSessionID,
                loadSummary: loadState.summary,
                draftProvider: shellState.selectedProvider,
                onStartTask: {
                    Task { await startProviderSession() }
                },
                isStartDisabled: !canStartProviderSession
            )
            .navigationSplitViewColumnWidth(
                min: CGFloat(WorkbenchShellLayoutGeometry.sidebarWidthRange.lowerBound),
                ideal: CGFloat(shellState.layout.sidebarWidth),
                max: CGFloat(WorkbenchShellLayoutGeometry.sidebarWidthRange.upperBound)
            )
            .onWorkbenchLayoutWidthChange(recordSidebarWidth)
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
                            pendingApproval: pendingApproval,
                            claudeReceiptSnapshot: claudeReceiptSnapshot,
                            claudeReceiptError: claudeReceiptError
                        ),
                        emptyState: currentTimelineEmptyState,
                        promptText: $promptText,
                        claudeReceiptPromptText: $claudeReceiptPromptText,
                        selectedProvider: $shellState.selectedProvider,
                        selectedModel: $shellState.selectedModel,
                        selectedEffort: $shellState.selectedEffort,
                        executionProfileStatus: executionProfileStatus,
                        executionProfileError: executionProfileError,
                        isExecutionProfileLoading: isExecutionProfileLoading,
                        claudeRuntimeStatus: claudeRuntimeStatus,
                        claudeRuntimeError: claudeRuntimeError,
                        isClaudeRuntimeLoading: isClaudeRuntimeLoading,
                        onStartSession: {
                            Task { await startProviderSession() }
                        },
                        onSubmit: {
                            Task { await submitTurn() }
                        },
                        isStartDisabled: !canStartProviderSession,
                        isSubmitDisabled: !canSubmitTurn
                    )
                    .frame(minWidth: 720)

                    if shellState.isInspectorVisible {
                        InspectorPanelView(
                            cards: seed.inspectorCards(
                                projectionKind: projectionKind,
                                sessionsCount: sessions.count,
                                selectedSession: selectedSession,
                                transcript: transcript,
                                pendingApproval: pendingApproval,
                                claudeReceiptSnapshot: claudeReceiptSnapshot
                            ),
                            selectedSession: selectedSession,
                            selectedProvider: shellState.selectedProvider,
                            terminalSurface: DaemonCodexTerminalSurfaceProjector.liveSurface(from: transcript),
                            gitReviewSnapshot: gitReviewSnapshot,
                            gitReviewError: gitReviewError,
                            isGitReviewLoading: isGitReviewLoading,
                            claudeRuntimeStatus: claudeRuntimeStatus,
                            claudeRuntimeError: claudeRuntimeError,
                            isClaudeRuntimeLoading: isClaudeRuntimeLoading,
                            selectedTab: $inspectorTab,
                            onRefreshGitReview: {
                                Task { await loadGitReview(selectedPath: gitReviewSelectedPath) }
                            },
                            onRefreshClaudeRuntime: {
                                Task { await loadClaudeRuntimeStatus() }
                            },
                            onSelectGitReviewPath: { path in
                                Task { await loadGitReview(selectedPath: path) }
                            },
                            commandExecProofMode: $commandExecProofMode,
                            commandExecStdinText: $commandExecStdinText,
                            commandExecSurface: commandExecSurface,
                            onRunCommandExec: {
                                Task { await runCommandExecControl() }
                            },
                            onSendCommandExecResize: resolveCommandExecResize,
                            onSendCommandExecWrite: resolveCommandExecWrite,
                            onSendCommandExecWriteAndClose: resolveCommandExecWriteAndClose,
                            onCloseCommandExecStdin: resolveCommandExecCloseStdin,
                            onTerminateCommandExec: resolveCommandExecTerminate,
                            isRunCommandExecDisabled: !canRunCommandExec,
                            isCommandExecResizeDisabled: !canSendCommandExecResize,
                            isCommandExecWriteDisabled: !canSendCommandExecWrite,
                            isCommandExecWriteAndCloseDisabled: !canSendCommandExecWriteAndClose,
                            isCommandExecCloseStdinDisabled: !canCloseCommandExecStdin,
                            isCommandExecTerminateDisabled: !canTerminateCommandExec
                        )
                        .frame(
                            minWidth: CGFloat(WorkbenchShellLayoutGeometry.inspectorWidthRange.lowerBound),
                            idealWidth: CGFloat(shellState.layout.inspectorWidth),
                            maxWidth: CGFloat(WorkbenchShellLayoutGeometry.inspectorWidthRange.upperBound)
                        )
                        .onWorkbenchLayoutWidthChange(recordInspectorWidth)
                    }
                }

                if shouldShowBottomComposer {
                    Divider()

                    ComposerBarView(
                        promptText: $promptText,
                        selectedProvider: $shellState.selectedProvider,
                        selectedModel: $shellState.selectedModel,
                        selectedEffort: $shellState.selectedEffort,
                        executionProfileStatus: executionProfileStatus,
                        executionProfileError: executionProfileError,
                        isExecutionProfileLoading: isExecutionProfileLoading,
                        claudeRuntimeStatus: claudeRuntimeStatus,
                        claudeRuntimeError: claudeRuntimeError,
                        isClaudeRuntimeLoading: isClaudeRuntimeLoading,
                        onSubmit: {
                            Task { await submitTurn() }
                        },
                        isSubmitDisabled: !canSubmitTurn
                    )
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(shellState.isInspectorVisible ? "Скрыть inspector" : "Показать inspector") {
                        shellState.isInspectorVisible.toggle()
                    }
                    .keyboardShortcut("i", modifiers: [.command, .option])
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .background {
            WorkbenchWindowSizeObserver(onContentSizeChange: recordWindowContentSize)
        }
        .task {
            await loadSessions(force: false, preferredSessionID: nil)
            await loadGitReview(selectedPath: gitReviewSelectedPath)
            await loadClaudeRuntimeStatus()
            await loadExecutionProfileStatus()
        }
        .task(id: shellState.selectedSessionID) {
            await loadTranscriptForSelection(force: true)
        }
        .onChange(of: shellState) { _, newValue in
            WorkbenchShellStateStore.save(newValue)
        }
        .onChange(of: commandExecProofMode) { _, newMode in
            guard !isCommandExecActive else {
                return
            }
            commandExecStdinText = newMode.defaultStdin
            commandExecSurface = nil
            commandExecContinuation = nil
            commandExecAllowsMoreControls = false
            commandExecResizeSent = false
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
    private func recordWindowContentSize(_ size: CGSize) {
        recordLayoutGeometry(
            windowWidth: Double(size.width),
            windowHeight: Double(size.height)
        )
    }

    @MainActor
    private func recordSidebarWidth(_ width: CGFloat) {
        recordLayoutGeometry(sidebarWidth: Double(width))
    }

    @MainActor
    private func recordInspectorWidth(_ width: CGFloat) {
        recordLayoutGeometry(inspectorWidth: Double(width))
    }

    @MainActor
    private func recordLayoutGeometry(
        windowWidth: Double? = nil,
        windowHeight: Double? = nil,
        sidebarWidth: Double? = nil,
        inspectorWidth: Double? = nil
    ) {
        var layout = shellState.layout

        if let windowWidth = normalizedLayoutDimension(windowWidth) {
            layout.windowWidth = windowWidth
        }

        if let windowHeight = normalizedLayoutDimension(windowHeight) {
            layout.windowHeight = windowHeight
        }

        if let sidebarWidth = normalizedLayoutDimension(sidebarWidth) {
            layout.sidebarWidth = sidebarWidth
        }

        if let inspectorWidth = normalizedLayoutDimension(inspectorWidth) {
            layout.inspectorWidth = inspectorWidth
        }

        let sanitizedLayout = layout.sanitized()
        guard sanitizedLayout != shellState.layout else {
            return
        }

        shellState.layout = sanitizedLayout
    }

    private func normalizedLayoutDimension(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value > 0 else {
            return nil
        }

        return value.rounded(.toNearestOrAwayFromZero)
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
            shellState.selectedSessionID = shellState.reconciledSelection(
                preferredSessionID: preferredSessionID,
                availableSessionIDs: projection.sessions.map(\.id),
                liveSessionPredicate: looksLikeLiveCodexThread
            )
            loadState = .loaded(kind: projection.kind, transport: "stdio pid=\(daemonPID)")
        } catch {
            sessions = []
            transcript = nil
            loadState = .failed(message: error.localizedDescription)
        }
    }

    @MainActor
    private func loadGitReview(selectedPath: String?) async {
        isGitReviewLoading = true
        gitReviewError = nil

        do {
            let snapshot = try await client.fetchGitReviewSnapshot(selectedPath: selectedPath)
            gitReviewSnapshot = snapshot
            gitReviewSelectedPath = snapshot.selectedPath
            isGitReviewLoading = false
        } catch {
            gitReviewSnapshot = nil
            gitReviewSelectedPath = selectedPath
            gitReviewError = error.localizedDescription
            isGitReviewLoading = false
        }
    }

    @MainActor
    private func loadClaudeRuntimeStatus() async {
        isClaudeRuntimeLoading = true
        claudeRuntimeError = nil

        do {
            claudeRuntimeStatus = try await client.fetchClaudeRuntimeStatus()
            isClaudeRuntimeLoading = false
        } catch {
            claudeRuntimeStatus = nil
            claudeRuntimeError = error.localizedDescription
            isClaudeRuntimeLoading = false
        }
    }

    @MainActor
    private func loadExecutionProfileStatus() async {
        isExecutionProfileLoading = true
        executionProfileError = nil

        do {
            executionProfileStatus = try await client.fetchExecutionProfileStatus()
            isExecutionProfileLoading = false
        } catch {
            executionProfileStatus = nil
            executionProfileError = error.localizedDescription
            isExecutionProfileLoading = false
        }
    }

    @MainActor
    private func startProviderSession() async {
        switch shellState.selectedProvider {
        case "Codex":
            await startCodexSession()
        case "Claude":
            await materializeClaudeReceiptSession()
        default:
            codexBootstrapState = .failed(message: startCodexBlockedMessage())
        }
    }

    @MainActor
    private func startCodexSession() async {
        guard canStartCodexSession else {
            codexBootstrapState = .failed(message: startCodexBlockedMessage())
            return
        }

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
    private func materializeClaudeReceiptSession() async {
        guard shellState.selectedProvider == "Claude" else {
            transcriptState = .unavailable(message: "Claude receipt можно запускать только из Claude provider state.")
            return
        }

        guard executionProfile(for: "Claude")?.isReceiptCapable == true else {
            transcriptState = .unavailable(message: "Claude capability status не разрешает receipt session. Путь закрыт fail-closed.")
            return
        }

        if let validationMessage = claudeReceiptPromptValidationMessage {
            transcriptState = .unavailable(message: validationMessage)
            return
        }

        let receiptPrompt = trimmedClaudeReceiptPrompt
        isClaudeProofRunning = true
        transcriptState = .streaming(summary: "Запускаем real Claude receipt proof через core-daemon.")

        do {
            let materialized = try await client.materializeClaudeProofSession(inputText: receiptPrompt)
            isClaudeProofRunning = false
            transcript = nil
            pendingApproval = nil
            transcriptState = materialized.proof.success
                ? .loaded(summary: "Claude receipt session materialized: \(materialized.proof.resultText). Диалоговый режим остаётся закрыт.")
                : .failed(message: "Claude receipt failed closed: \(materialized.proof.warnings.joined(separator: "; "))")
            await loadSessions(force: true, preferredSessionID: materialized.session.id)
            await loadClaudeReceiptSnapshot(sessionID: materialized.session.id)
        } catch {
            isClaudeProofRunning = false
            transcriptState = .failed(message: error.localizedDescription)
        }
    }

    @MainActor
    private func loadTranscriptForSelection(force: Bool) async {
        guard let selectedSession else {
            transcript = nil
            transcriptState = .idle
            claudeReceiptSnapshot = nil
            claudeReceiptError = nil
            return
        }

        guard looksLikeLiveCodexThread(selectedSession.id) else {
            transcript = nil
            if selectedSession.provider == "Claude", selectedSession.status.hasPrefix("receipt_") {
                await loadClaudeReceiptSnapshot(sessionID: selectedSession.id)
                return
            }
            claudeReceiptSnapshot = nil
            claudeReceiptError = nil
            transcriptState = .unavailable(message: "Эта session seeded. Нажми Запустить, чтобы создать живую Codex session.")
            return
        }

        claudeReceiptSnapshot = nil
        claudeReceiptError = nil
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
    private func loadClaudeReceiptSnapshot(sessionID: String) async {
        do {
            let snapshot = try await client.fetchClaudeReceiptSnapshot(sessionId: sessionID)
            claudeReceiptSnapshot = snapshot
            claudeReceiptError = nil
            transcriptState = snapshot.proof.success
                ? .loaded(summary: "Claude receipt snapshot loaded: \(snapshot.proof.resultText). Диалоговый режим остаётся закрыт.")
                : .failed(message: "Claude receipt snapshot loaded as failed: \(snapshot.proof.warnings.joined(separator: "; "))")
        } catch {
            claudeReceiptSnapshot = nil
            claudeReceiptError = error.localizedDescription
            transcriptState = .unavailable(message: "Claude receipt session read-only, but detail snapshot is unavailable: \(error.localizedDescription)")
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

        guard canSubmitTurn else {
            transcriptState = .unavailable(message: turnSubmitBlockedMessage(for: selectedSession))
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
            await loadGitReview(selectedPath: gitReviewSelectedPath)
        } catch {
            pendingApproval = nil
            transcriptState = transcriptUnavailableState(for: error)
        }
    }

    @MainActor
    private func runCommandExecControl() async {
        let argv = commandExecCommand
        guard !argv.isEmpty else {
            commandExecSurface = DaemonCodexCommandExecControlSurface(
                command: [],
                processId: "",
                mergedOutput: "",
                stdout: "",
                stderr: "",
                controlTrail: "",
                exitCode: nil,
                stage: .failed,
                lastError: "Нужен хотя бы один argv line."
            )
            return
        }

        let processId = "openslop-command-exec-ui-\(UUID().uuidString)"
        commandExecContinuation = nil
        commandExecAllowsMoreControls = true
        commandExecResizeSent = false
        commandExecStdinText = commandExecProofMode.defaultStdin
        commandExecSurface = DaemonCodexCommandExecControlSurfaceProjector.start(
            command: argv,
            processId: processId
        )

        do {
            let result = try await client.streamCodexCommandWithControl(
                command: argv,
                processId: processId,
                tty: commandExecProofMode == .ptyResize,
                size: commandExecProofMode == .ptyResize
                    ? DaemonCodexCommandExecProofCommand.ptyResizeInitialSize
                    : nil
            ) { outputEvent in
                if await MainActor.run(body: { self.commandExecAllowsMoreControls }) {
                    await MainActor.run {
                        if let commandExecSurface {
                            self.commandExecSurface = DaemonCodexCommandExecControlSurfaceProjector.recordOutput(
                                outputEvent,
                                nextStage: .awaitingControl,
                                to: commandExecSurface
                            )
                        }
                    }
                    return await awaitCommandExecControl()
                }

                await MainActor.run {
                    if let commandExecSurface {
                        self.commandExecSurface = DaemonCodexCommandExecControlSurfaceProjector.recordOutput(
                            outputEvent,
                            nextStage: .running,
                            to: commandExecSurface
                        )
                    }
                }
                return nil
            }

            if let commandExecSurface {
                self.commandExecSurface = DaemonCodexCommandExecControlSurfaceProjector.complete(
                    result,
                    to: commandExecSurface
                )
            }
            commandExecContinuation = nil
            commandExecAllowsMoreControls = false
            commandExecResizeSent = false
        } catch {
            if let commandExecSurface {
                self.commandExecSurface = DaemonCodexCommandExecControlSurfaceProjector.fail(
                    error.localizedDescription,
                    on: commandExecSurface
                )
            } else {
                commandExecSurface = DaemonCodexCommandExecControlSurface(
                    command: argv,
                    processId: processId,
                    mergedOutput: "",
                    stdout: "",
                    stderr: "",
                    controlTrail: "",
                    exitCode: nil,
                    stage: .failed,
                    lastError: error.localizedDescription
                )
            }
            commandExecContinuation = nil
            commandExecAllowsMoreControls = false
            commandExecResizeSent = false
        }
    }

    @MainActor
    private func awaitCommandExecControl() async -> DaemonCodexCommandExecControlRequest? {
        await withCheckedContinuation { continuation in
            commandExecContinuation = continuation
        }
    }

    @MainActor
    private func resolveCommandExecWrite() {
        guard
            let commandExecSurface,
            commandExecSurface.stage == .awaitingControl,
            let continuation = commandExecContinuation
        else {
            return
        }

        commandExecContinuation = nil
        commandExecAllowsMoreControls = true
        self.commandExecSurface = DaemonCodexCommandExecControlSurfaceProjector.markWrite(
            raw: commandExecStdinText,
            on: commandExecSurface
        )
        continuation.resume(
            returning: .write(
                DaemonCodexCommandExecWriteRequest(
                    processId: commandExecSurface.processId,
                    deltaBase64: Data(commandExecStdinText.utf8).base64EncodedString(),
                    closeStdin: false
                )
            )
        )
    }

    @MainActor
    private func resolveCommandExecResize() {
        guard
            let commandExecSurface,
            commandExecSurface.stage == .awaitingControl,
            let continuation = commandExecContinuation
        else {
            return
        }

        let targetSize = DaemonCodexCommandExecProofCommand.ptyResizeTargetSize
        commandExecContinuation = nil
        commandExecAllowsMoreControls = true
        commandExecResizeSent = true
        self.commandExecSurface = DaemonCodexCommandExecControlSurfaceProjector.markResize(
            size: targetSize,
            on: commandExecSurface
        )
        continuation.resume(
            returning: .resize(
                DaemonCodexCommandExecResizeRequest(
                    processId: commandExecSurface.processId,
                    size: targetSize
                )
            )
        )
    }

    @MainActor
    private func resolveCommandExecWriteAndClose() {
        guard
            let commandExecSurface,
            commandExecSurface.stage == .awaitingControl,
            let continuation = commandExecContinuation
        else {
            return
        }

        commandExecContinuation = nil
        commandExecAllowsMoreControls = false
        self.commandExecSurface =
            DaemonCodexCommandExecControlSurfaceProjector.markWriteAndCloseStdin(
                raw: commandExecStdinText,
                on: commandExecSurface
            )
        continuation.resume(
            returning: .write(
                DaemonCodexCommandExecWriteRequest(
                    processId: commandExecSurface.processId,
                    deltaBase64: Data(commandExecStdinText.utf8).base64EncodedString(),
                    closeStdin: true
                )
            )
        )
    }

    @MainActor
    private func resolveCommandExecCloseStdin() {
        guard
            let commandExecSurface,
            commandExecSurface.stage == .awaitingControl,
            let continuation = commandExecContinuation
        else {
            return
        }

        commandExecContinuation = nil
        commandExecAllowsMoreControls = false
        commandExecResizeSent = false
        self.commandExecSurface = DaemonCodexCommandExecControlSurfaceProjector.markCloseStdin(
            on: commandExecSurface
        )
        continuation.resume(
            returning: .write(
                DaemonCodexCommandExecWriteRequest(
                    processId: commandExecSurface.processId,
                    deltaBase64: nil,
                    closeStdin: true
                )
            )
        )
    }

    @MainActor
    private func resolveCommandExecTerminate() {
        guard
            let commandExecSurface,
            commandExecSurface.stage == .awaitingControl,
            let continuation = commandExecContinuation
        else {
            return
        }

        commandExecContinuation = nil
        commandExecAllowsMoreControls = false
        commandExecResizeSent = false
        self.commandExecSurface = DaemonCodexCommandExecControlSurfaceProjector.markTerminate(
            on: commandExecSurface
        )
        continuation.resume(
            returning: .terminate(
                DaemonCodexCommandExecTerminateRequest(processId: commandExecSurface.processId)
            )
        )
    }

    private func startCodexBlockedMessage() -> String {
        if isExecutionProfileLoading {
            return "Capability status ещё загружается. Start закрыт fail-closed."
        }

        if let executionProfileError {
            return "Capability status недоступен: \(executionProfileError)"
        }

        if shellState.selectedProvider == "Claude" {
            if isClaudeProofRunning {
                return "Claude receipt proof уже выполняется."
            }
            if executionProfile(for: "Claude")?.isReceiptCapable != true {
                return "Claude capability status не разрешает receipt. Путь закрыт fail-closed."
            }
            return "Claude может создать только read-only receipt session. Диалоговый режим ещё закрыт."
        }

        if isCodexBootstrapRunning {
            return "Codex session уже запускается."
        }

        if executionProfile(for: "Codex")?.isSubmitCapable != true {
            return "Codex capability status не разрешает live session. Start закрыт fail-closed."
        }

        return "Codex start сейчас закрыт fail-closed: provider=\(shellState.selectedProvider)."
    }

    private func turnSubmitBlockedMessage(for selectedSession: DaemonSessionSummary) -> String {
        if shellState.selectedProvider == "Claude" {
            return "Claude runtime найден как status/proof boundary. Диалоговый режим закрыт до session lifecycle slice."
        }

        if executionProfile(for: "Codex")?.isSubmitCapable != true {
            return "Codex capability status не разрешает submit. Turn закрыт fail-closed."
        }

        if isTurnStreaming {
            return "Turn уже выполняется. Дождись terminal state перед следующим submit."
        }

        if !looksLikeLiveCodexThread(selectedSession.id) {
            return "Выбранная session не является живым Codex thread. Сначала запусти новую Codex session."
        }

        return "Submit сейчас закрыт fail-closed: provider=\(shellState.selectedProvider), session=\(selectedSession.id)."
    }

    private func looksLikeLiveCodexThread(_ value: String) -> Bool {
        value.count == 36 && value.filter { $0 == "-" }.count >= 4
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
