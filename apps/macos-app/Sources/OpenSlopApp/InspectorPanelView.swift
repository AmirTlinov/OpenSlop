import SwiftUI
import WorkbenchCore

enum InspectorPanelTab: String, CaseIterable, Identifiable {
    case summary = "Сводка"
    case verify = "Проверка"
    case browser = "Браузер"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .summary: "list.bullet.rectangle"
        case .verify: "checklist"
        case .browser: "globe"
        }
    }
}

struct InspectorPanelView: View {
    let cards: [InspectorCardSeed]
    let selectedProvider: String
    let terminalSurface: DaemonCodexTerminalSurface?
    let gitReviewSnapshot: DaemonGitReviewSnapshot?
    let gitReviewError: String?
    let isGitReviewLoading: Bool
    let claudeRuntimeStatus: DaemonClaudeRuntimeStatus?
    let claudeRuntimeError: String?
    let isClaudeRuntimeLoading: Bool
    @Binding var selectedTab: InspectorPanelTab
    let onRefreshGitReview: () -> Void
    let onRefreshClaudeRuntime: () -> Void
    let onSelectGitReviewPath: (String?) -> Void
    @Binding var commandExecProofMode: CommandExecProofMode
    @Binding var commandExecStdinText: String
    let commandExecSurface: DaemonCodexCommandExecControlSurface?
    let onRunCommandExec: () -> Void
    let onSendCommandExecResize: () -> Void
    let onSendCommandExecWrite: () -> Void
    let onSendCommandExecWriteAndClose: () -> Void
    let onCloseCommandExecStdin: () -> Void
    let onTerminateCommandExec: () -> Void
    let isRunCommandExecDisabled: Bool
    let isCommandExecResizeDisabled: Bool
    let isCommandExecWriteDisabled: Bool
    let isCommandExecWriteAndCloseDisabled: Bool
    let isCommandExecCloseStdinDisabled: Bool
    let isCommandExecTerminateDisabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                ForEach(InspectorPanelTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Label(tab.rawValue, systemImage: tab.systemImage)
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(selectedTab == tab ? Color.secondary.opacity(0.12) : Color.clear, in: Capsule())
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            Divider()

            Group {
                switch selectedTab {
                case .summary:
                    summaryPane
                case .verify:
                    verifyPane
                case .browser:
                    browserPane
                }
            }
        }
        .background(.bar)
    }

    private var summaryPane: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if selectedProvider == "Claude" {
                    ClaudeRuntimeStatusView(
                        status: claudeRuntimeStatus,
                        errorMessage: claudeRuntimeError,
                        isLoading: isClaudeRuntimeLoading,
                        onRefresh: onRefreshClaudeRuntime
                    )
                }

                GitReviewPaneView(
                    snapshot: gitReviewSnapshot,
                    errorMessage: gitReviewError,
                    isLoading: isGitReviewLoading,
                    onRefresh: onRefreshGitReview,
                    onSelectPath: onSelectGitReviewPath
                )

                ForEach(humanCards) { card in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(card.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(card.value)
                            .font(.body)
                            .lineLimit(3)
                            .textSelection(.enabled)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                if let terminalSurface {
                    TerminalPaneView(surface: terminalSurface)
                }

                CommandExecControlPaneView(
                    proofMode: $commandExecProofMode,
                    stdinText: $commandExecStdinText,
                    surface: commandExecSurface,
                    onRun: onRunCommandExec,
                    onSendResize: onSendCommandExecResize,
                    onSendWrite: onSendCommandExecWrite,
                    onSendWriteAndClose: onSendCommandExecWriteAndClose,
                    onCloseStdin: onCloseCommandExecStdin,
                    onTerminate: onTerminateCommandExec,
                    isRunDisabled: isRunCommandExecDisabled,
                    isResizeDisabled: isCommandExecResizeDisabled,
                    isWriteDisabled: isCommandExecWriteDisabled,
                    isWriteAndCloseDisabled: isCommandExecWriteAndCloseDisabled,
                    isCloseStdinDisabled: isCommandExecCloseStdinDisabled,
                    isTerminateDisabled: isCommandExecTerminateDisabled
                )
            }
            .padding(16)
        }
    }

    private var verifyPane: some View {
        VStack(spacing: 0) {
            verifyRow("Git snapshot", state: gitReviewSnapshot?.statusState.uppercased() ?? "UNKNOWN", systemImage: "point.3.connected.trianglepath.dotted")
            Divider()
            verifyRow("Runtime transcript", state: cards.first(where: { $0.id == "turns" })?.value == "0" ? "UNKNOWN" : "OBSERVED", systemImage: "text.bubble")
            Divider()
            verifyRow("Harness gates", state: "PLANNED S09/S10", systemImage: "checkmark.seal")
            Spacer()
            ContentUnavailableView(
                "Проверка ещё не harness",
                systemImage: "checklist.unchecked",
                description: Text("Этот таб честно показывает только текущие известные сигналы. Полный fail-closed verify появится в S09/S10.")
            )
            .padding(24)
            Spacer()
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var browserPane: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "chevron.left")
                    .foregroundStyle(.tertiary)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(.secondary)
                TextField("Введите URL", text: .constant(""))
                    .textFieldStyle(.roundedBorder)
                    .disabled(true)
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(.secondary)
            }
            .padding(14)

            Divider()

            ZStack {
                Color(nsColor: .textBackgroundColor)
                VStack(spacing: 10) {
                    Image(systemName: "globe")
                        .font(.system(size: 30))
                        .foregroundStyle(.tertiary)
                    Text("Пустая страница")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Native preview browser запланирован в S07. Сейчас этот таб только резервирует правильную поверхность.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 280)
                }
            }
        }
    }

    private var humanCards: [InspectorCardSeed] {
        cards.compactMap { card in
            switch card.id {
            case "projection":
                nil
            case "sessions":
                InspectorCardSeed(id: card.id, title: "Сессии", value: card.value)
            case "provider":
                InspectorCardSeed(id: card.id, title: "Provider", value: card.value)
            case "branch":
                InspectorCardSeed(id: card.id, title: "Branch", value: card.value)
            case "thread":
                InspectorCardSeed(id: card.id, title: "Thread", value: shortValue(card.value))
            case "turns":
                InspectorCardSeed(id: card.id, title: "Turns", value: card.value)
            case "last-turn":
                InspectorCardSeed(id: card.id, title: "Last turn", value: card.value)
            default:
                card
            }
        }
    }

    private func verifyRow(_ title: String, state: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
            Text(title)
            Spacer()
            Text(state)
                .font(.caption.weight(.semibold))
                .foregroundStyle(state == "DIRTY" || state == "UNKNOWN" ? .orange : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary, in: Capsule())
        }
        .font(.callout)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private func shortValue(_ value: String) -> String {
        guard value.count > 16 else {
            return value
        }
        return String(value.prefix(8)) + "…" + String(value.suffix(4))
    }
}
