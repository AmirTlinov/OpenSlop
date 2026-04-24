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
    let selectedProvider: String
    let terminalSurface: DaemonCodexTerminalSurface?
    let gitReviewSnapshot: DaemonGitReviewSnapshot?
    let gitReviewError: String?
    let isGitReviewLoading: Bool
    let claudeRuntimeStatus: DaemonClaudeRuntimeStatus?
    let claudeRuntimeError: String?
    let isClaudeRuntimeLoading: Bool
    let activePlanProjection: DaemonActivePlanProjection?
    let activePlanError: String?
    let isActivePlanLoading: Bool
    @Binding var selectedTab: InspectorPanelTab
    let onRefreshGitReview: () -> Void
    let onRefreshClaudeRuntime: () -> Void
    let onRefreshActivePlan: () -> Void
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
                if let activePlanProjection {
                    if activePlanProjection.isUnavailable {
                        unavailablePlanProjection(activePlanProjection)
                    } else {
                        activePlanHeader(activePlanProjection)
                        activeSliceCard(activePlanProjection.activeSlice)
                        ForEach(visiblePlanSlices(activePlanProjection)) { slice in
                            activePlanSliceRow(slice)
                        }

                        if activePlanProjection.slices.count > visiblePlanSlices(activePlanProjection).count {
                            Text("Показан ближайший участок плана: \(visiblePlanSlices(activePlanProjection).count) из \(activePlanProjection.slices.count). Полная правда остаётся в ROADMAP.md.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 12)
                        }

                        if !activePlanProjection.warnings.isEmpty {
                            warningsCard(activePlanProjection.warnings)
                        }
                    }
                } else if isActivePlanLoading {
                    ProgressView("Загружаем план из core-daemon…")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                } else {
                    ContentUnavailableView(
                        "План недоступен",
                        systemImage: "map",
                        description: Text(activePlanError ?? "core-daemon пока не вернул active plan projection.")
                    )
                    .padding(.top, 10)
                }
            }
            .padding(16)
        }
    }

    private func unavailablePlanProjection(_ projection: DaemonActivePlanProjection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("План не доказан", systemImage: "exclamationmark.triangle")
                .font(.headline)
                .foregroundStyle(.orange)
            Text(projection.selectionReason)
                .font(.callout)
                .foregroundStyle(.secondary)
            if !projection.warnings.isEmpty {
                warningsCard(projection.warnings)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func activePlanHeader(_ projection: DaemonActivePlanProjection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "map")
                    .foregroundStyle(.secondary)
                Text("Вертикальные слайсы")
                    .font(.headline)
                Spacer()
                Button(action: onRefreshActivePlan) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .disabled(isActivePlanLoading)
                .accessibilityLabel("Обновить план")
            }

            HStack(spacing: 8) {
                planCountChip("готово", value: projection.counts.done, tone: .green)
                planCountChip("активно", value: projection.counts.active, tone: .blue)
                planCountChip("план", value: projection.counts.planned, tone: .secondary)
            }

            if let activeSlice = projection.activeSlice {
                Text("Сейчас: \(activeSlice.id)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(projection.selectionReason)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func activeSliceCard(_ slice: DaemonActivePlanSlice?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Фокус плана")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let slice {
                Text(slice.id)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                Text(slice.outcome)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                reviewMarkerRow(slice)
            } else {
                Text("Все слайсы закрыты.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func activePlanSliceRow(_ slice: DaemonActivePlanSlice) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(statusColor(slice.status).opacity(0.22))
                .frame(width: 10, height: 10)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(slice.id)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    statusChip(slice.status, value: slice.status)
                }

                Text(slice.outcome)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                reviewMarkerRow(slice)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(slice.id == activePlanProjection?.activeSliceId ? Color.accentColor.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func visiblePlanSlices(_ projection: DaemonActivePlanProjection) -> [DaemonActivePlanSlice] {
        guard !projection.slices.isEmpty else {
            return []
        }

        if let activeSliceId = projection.activeSliceId,
           let index = projection.slices.firstIndex(where: { $0.id == activeSliceId })
        {
            let lower = max(0, index - 3)
            let upper = min(projection.slices.count, index + 5)
            return Array(projection.slices[lower..<upper])
        }

        return Array(projection.slices.suffix(8))
    }

    private func reviewMarkerRow(_ slice: DaemonActivePlanSlice) -> some View {
        HStack(spacing: 6) {
            statusChip("proof", value: slice.proofStatus)
            statusChip("review", value: slice.reviewStatus)
            statusChip("visual", value: slice.visualStatus)
        }
        .font(.caption2.weight(.semibold))
    }

    private func warningsCard(_ warnings: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Предупреждения плана")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
            ForEach(warnings, id: \.self) { warning in
                Text(warning)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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

    private func planCountChip(_ title: String, value: Int, tone: Color) -> some View {
        Text("\(value) \(title)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(tone)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tone.opacity(0.1), in: Capsule())
    }

    private func statusChip(_ title: String, value: String) -> some View {
        Text(title == value ? value : "\(title) \(value)")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(statusColor(value))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(statusColor(value).opacity(0.1), in: Capsule())
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "done", "pass":
            return .green
        case "in-progress", "in-review", "active":
            return .blue
        case "blocked", "block", "fail", "missing", "unknown", "pending":
            return .orange
        default:
            return .secondary
        }
    }

    private func shortValue(_ value: String) -> String {
        guard value.count > 16 else {
            return value
        }
        return String(value.prefix(8)) + "…" + String(value.suffix(4))
    }
}
