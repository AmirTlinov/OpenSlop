import SwiftUI
import WorkbenchCore

struct TimelinePanelView: View {
    let session: DaemonSessionSummary?
    let loadSummary: String
    let transcriptSummary: String
    let timeline: [TimelineItemSeed]
    let emptyState: WorkbenchTimelineEmptyState?
    @Binding var promptText: String
    @Binding var claudeReceiptPromptText: String
    @Binding var selectedProvider: String
    @Binding var selectedModel: String
    @Binding var selectedEffort: String
    let executionProfileStatus: DaemonExecutionProfileStatus?
    let executionProfileError: String?
    let isExecutionProfileLoading: Bool
    let claudeRuntimeStatus: DaemonClaudeRuntimeStatus?
    let claudeRuntimeError: String?
    let isClaudeRuntimeLoading: Bool
    let onStartSession: () -> Void
    let onSubmit: () -> Void
    let isStartDisabled: Bool
    let isSubmitDisabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if timeline.isEmpty, let emptyState {
                WorkbenchStartSurfaceView(
                    emptyState: emptyState,
                    promptText: $promptText,
                    claudeReceiptPromptText: $claudeReceiptPromptText,
                    selectedProvider: $selectedProvider,
                    selectedModel: $selectedModel,
                    selectedEffort: $selectedEffort,
                    executionProfileStatus: executionProfileStatus,
                    executionProfileError: executionProfileError,
                    isExecutionProfileLoading: isExecutionProfileLoading,
                    claudeRuntimeStatus: claudeRuntimeStatus,
                    claudeRuntimeError: claudeRuntimeError,
                    isClaudeRuntimeLoading: isClaudeRuntimeLoading,
                    workspaceTitle: session?.workspace ?? "OpenSlop",
                    branchTitle: session?.branch ?? "main",
                    onStartSession: onStartSession,
                    onSubmit: onSubmit,
                    isStartDisabled: isStartDisabled,
                    isSubmitDisabled: isSubmitDisabled
                )
            } else {
                timelineContent
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var timelineContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(session?.title ?? "Session list unavailable")
                        .font(.title2.weight(.semibold))
                        .lineLimit(2)
                    Text(headerSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                statusBadge
            }
            .padding(20)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(timeline.enumerated()), id: \.element.id) { index, item in
                        TimelineEventRow(
                            item: item,
                            isLast: index == timeline.count - 1
                        )
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 20)
            }
        }
    }

    private var headerBadgeTitle: String {
        guard let session else {
            return "Пусто"
        }
        return humanStatus(session.status)
    }

    private var headerBadgeSystemImage: String {
        session == nil ? "rectangle.stack" : "circle.fill"
    }

    private var headerSubtitle: String {
        if let session {
            return "\(session.workspace) · \(session.branch) · \(session.provider)"
        }
        return loadSummary
    }

    private var statusBadge: some View {
        Label(headerBadgeTitle, systemImage: headerBadgeSystemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(statusBadgeColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(statusBadgeColor.opacity(0.11), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(statusBadgeColor.opacity(0.2), lineWidth: 1)
            }
    }

    private var statusBadgeColor: Color {
        switch session?.status {
        case "in_progress":
            return .blue
        case "needs_first_turn":
            return .secondary
        case "receipt_proven":
            return .green
        case "receipt_failed":
            return .orange
        default:
            return .secondary
        }
    }

    private func humanStatus(_ status: String) -> String {
        switch status {
        case "needs_first_turn":
            return "ждёт первого сообщения"
        case "notLoaded":
            return "архив"
        case "in_progress":
            return "в работе"
        case "receipt_proven":
            return "receipt готов"
        case "receipt_failed":
            return "receipt failed"
        default:
            return status.replacingOccurrences(of: "_", with: " ")
        }
    }
}

private struct TimelineEventRow: View {
    let item: TimelineItemSeed
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            rail

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.kind.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(accentColor.opacity(0.1), in: Capsule())

                    Text(displayTitle)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Spacer(minLength: 0)

                    Text(item.statusLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.1), in: Capsule())
                }

                if !primaryDetail.isEmpty {
                    Text(primaryDetail)
                        .font(primaryDetailFont)
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if hasCollapsedPrimaryDetail {
                    DisclosureGroup("Полный текст") {
                        Text(item.detail)
                            .font(item.prefersMonospacedDetail ? .footnote.monospaced() : .footnote)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 6)
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                }

                if let secondaryDetail = item.secondaryDetail, !secondaryDetail.isEmpty {
                    DisclosureGroup(secondaryDisclosureTitle) {
                        Text(secondaryDetail)
                            .font(.footnote.monospaced())
                            .foregroundStyle(.tertiary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 6)
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(alignment: .topLeading) {
            if !isLast {
                Rectangle()
                    .fill(.separator.opacity(0.55))
                    .frame(width: 1)
                    .padding(.leading, 14.5)
                    .padding(.top, 30)
                    .padding(.bottom, -14)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var rail: some View {
        ZStack {
            Circle()
                .fill(accentColor.opacity(0.13))
                .frame(width: 28, height: 28)
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(accentColor)
        }
        .overlay {
            Circle()
                .stroke(accentColor.opacity(0.24), lineWidth: 1)
        }
        .frame(width: 30)
    }

    private var displayTitle: String {
        switch item.title {
        case "User prompt":
            return "Задача от вас"
        case "Assistant reply":
            return "Ответ агента"
        case "Command running":
            return "Команда выполняется"
        case "Command completed":
            return "Команда выполнена"
        case "Command failed":
            return "Команда завершилась ошибкой"
        case "Command declined":
            return "Команда отклонена"
        case "File change running":
            return "Файлы меняются"
        case "File change completed":
            return "Файлы обновлены"
        case "File change failed":
            return "Изменения файлов не прошли"
        case "File change declined":
            return "Изменения файлов отклонены"
        default:
            return item.title
        }
    }

    private var primaryDetail: String {
        if hasCollapsedPrimaryDetail {
            return preview(item.detail, maxCharacters: item.prefersMonospacedDetail ? 180 : 720)
        }
        return item.detail
    }

    private var hasCollapsedPrimaryDetail: Bool {
        item.detail.count > (item.prefersMonospacedDetail ? 220 : 900)
    }

    private var primaryDetailFont: Font {
        item.prefersMonospacedDetail ? .callout.monospaced() : .callout
    }

    private var secondaryDisclosureTitle: String {
        switch item.kind {
        case .command:
            return "Вывод и параметры"
        case .fileChange:
            return "Файловый след"
        case .tool:
            return "Технический след"
        case .verify:
            return "Доказательства"
        default:
            return "Подробности"
        }
    }

    private var systemImage: String {
        switch item.kind {
        case .user:
            return "person.fill"
        case .agent:
            return "sparkles"
        case .command:
            return "terminal"
        case .fileChange:
            return "doc.text"
        case .tool:
            return "wrench.and.screwdriver"
        case .verify:
            return "checkmark.seal"
        }
    }

    private var accentColor: Color {
        switch item.kind {
        case .user:
            return .accentColor
        case .agent:
            return .purple
        case .command:
            return .blue
        case .fileChange:
            return .green
        case .tool:
            return .orange
        case .verify:
            return .teal
        }
    }

    private var statusColor: Color {
        switch item.statusTone {
        case .neutral:
            return .secondary
        case .running:
            return .blue
        case .success:
            return .green
        case .attention:
            return .orange
        case .unknown:
            return .orange
        }
    }

    private func preview(_ value: String, maxCharacters: Int) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxCharacters else {
            return trimmed
        }
        return String(trimmed.prefix(maxCharacters)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}
