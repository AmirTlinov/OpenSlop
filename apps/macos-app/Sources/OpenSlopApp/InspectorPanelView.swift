import SwiftUI
import WorkbenchCore

struct InspectorPanelView: View {
    let cards: [InspectorCardSeed]
    let terminalSurface: DaemonCodexTerminalSurface?
    let gitReviewSnapshot: DaemonGitReviewSnapshot?
    let gitReviewError: String?
    let isGitReviewLoading: Bool
    let onRefreshGitReview: () -> Void
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
            Text("Inspector")
                .font(.title3.weight(.semibold))
                .padding(20)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(cards) { card in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(card.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(card.value)
                                .font(.body)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
                    }

                    GitReviewPaneView(
                        snapshot: gitReviewSnapshot,
                        errorMessage: gitReviewError,
                        isLoading: isGitReviewLoading,
                        onRefresh: onRefreshGitReview,
                        onSelectPath: onSelectGitReviewPath
                    )

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
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
