import SwiftUI
import WorkbenchCore

enum InspectorPanelTab: String, CaseIterable, Identifiable {
    case plan = "План"
    case evidence = "Следы"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .plan: "list.bullet.rectangle"
        case .evidence: "checkmark.seal"
        }
    }
}

struct InspectorPanelView: View {
    let cards: [InspectorCardSeed]
    let selectedSession: DaemonSessionSummary?
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
                case .plan:
                    planPane
                case .evidence:
                    evidencePane
                }
            }
        }
        .background(.bar)
    }

    private var planPane: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "target")
                            .foregroundStyle(.secondary)
                        Text("Текущая работа")
                            .font(.headline)
                    }

                    Text(currentWorkTitle)
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)

                    Text(currentWorkDetail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 10) {
                    planMarker("Реализация", value: selectedStatusValue, systemImage: "hammer")
                    planMarker("Локальная проверка", value: localProofValue, systemImage: "checkmark.seal")
                    planMarker("Ревью субагентом", value: "UNKNOWN", systemImage: "person.2")
                    planMarker("Визуальная сверка", value: "UNKNOWN", systemImage: "rectangle.on.rectangle")
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                ContentUnavailableView(
                    "Active plan projection ещё не подключён",
                    systemImage: "map",
                    description: Text("Этот экран больше не притворяется полной проверкой. Вертикальные слайсы и review markers должны прийти из daemon-owned projection в S10a/S12a.")
                )
                .padding(.top, 10)
            }
            .padding(16)
        }
    }

    private var evidencePane: some View {
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

    private var currentWorkTitle: String {
        selectedSession?.title ?? "Новая задача"
    }

    private var currentWorkDetail: String {
        let provider = cardValue("provider") ?? selectedProvider
        let branch = cardValue("branch") ?? "—"
        let turns = cardValue("turns") ?? "0"
        return "\(provider) · \(branch) · \(turns) наблюдаемых ходов. Подробные доказательства лежат во вкладке «Следы»."
    }

    private var selectedStatusValue: String {
        if let approval = cardValue("approval"), !approval.isEmpty {
            return "NEEDS APPROVAL"
        }
        if let turns = cardValue("turns"), turns != "0" {
            return "OBSERVED"
        }
        return "UNKNOWN"
    }

    private var localProofValue: String {
        gitReviewSnapshot?.statusState.uppercased() ?? "UNKNOWN"
    }

    private func cardValue(_ id: String) -> String? {
        cards.first(where: { $0.id == id })?.value
    }

    private func planMarker(_ title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
            Text(title)
            Spacer()
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(value == "UNKNOWN" || value == "DIRTY" ? .orange : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary, in: Capsule())
        }
        .font(.callout)
    }

    private func shortValue(_ value: String) -> String {
        guard value.count > 16 else {
            return value
        }
        return String(value.prefix(8)) + "…" + String(value.suffix(4))
    }
}
