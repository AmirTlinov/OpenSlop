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
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session?.title ?? "Session list unavailable")
                        .font(.title2.weight(.semibold))
                    Text(headerSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Label(headerBadgeTitle, systemImage: headerBadgeSystemImage)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.quaternary, in: Capsule())
            }
            .padding(20)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(timeline) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.kind.rawValue)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(item.title)
                                .font(.headline)
                            Text(item.detail)
                                .font(item.prefersMonospacedDetail ? .body.monospaced() : .body)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)

                            if let secondaryDetail = item.secondaryDetail, !secondaryDetail.isEmpty {
                                Text(secondaryDetail)
                                    .font(item.prefersMonospacedDetail ? .footnote.monospaced() : .footnote)
                                    .foregroundStyle(.tertiary)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(20)
            }
        }
    }

    private var headerBadgeTitle: String {
        session?.status.capitalized ?? "Empty"
    }

    private var headerBadgeSystemImage: String {
        session == nil ? "rectangle.stack" : "circle.fill"
    }

    private var headerSubtitle: String {
        if let session {
            return "\(session.workspace) · \(session.branch) · \(session.provider) · \(humanStatus(session.status))"
        }
        return loadSummary
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
