import Darwin
import Foundation
import WorkbenchCore

@main
struct OpenSlopTerminalInteractionProbe {
    private static let prompt = """
    Use the shell to run exactly: python3 -c "print('READY'); input(); print('DONE')".
    Do not skip the command.
    After you observe what happens, reply with exactly FINISHED.
    """

    static func main() async {
        let client = CoreDaemonClient()

        for attempt in 1...3 {
            do {
                let recorder = StreamRecorder()
                let bootstrap = try await client.startCodexSession()
                let transcript = try await client.streamCodexTurn(
                    sessionId: bootstrap.session.id,
                    inputText: prompt
                ) { snapshot in
                    await recorder.record(snapshot)
                } onApprovalRequest: { approval in
                    await recorder.recordApproval(approval)
                    return .accept
                }

                let streamedSnapshots = await recorder.snapshots()
                let approvals = await recorder.approvals()
                let liveItems = ([transcript] + streamedSnapshots).flatMap(\.items)
                let liveCommandItems = liveItems.filter { $0.kind == "command" }
                let streamedTerminalItems = streamedSnapshots
                    .flatMap(\.items)
                    .filter { $0.kind == "command" && (($0.terminalStdin ?? "").isEmpty == false) }
                let liveTerminalItems = liveCommandItems.filter {
                    ($0.terminalStdin ?? "").isEmpty == false
                }
                let finalTerminalItems = transcript.items.filter {
                    $0.kind == "command" && (($0.terminalStdin ?? "").isEmpty == false)
                }
                let readback = try await client.fetchCodexTranscript(sessionId: bootstrap.session.id)
                let readbackCommandItems = readback.items.filter { $0.kind == "command" }
                let containsFinished = transcript.items.contains {
                    $0.kind == "agent" && $0.text.trimmingCharacters(in: .whitespacesAndNewlines) == "FINISHED"
                }
                let liveTerminalItemIDs = Array(Set(liveTerminalItems.map(\.id))).sorted()
                let finalTerminalItemIDs = Array(Set(finalTerminalItems.map(\.id))).sorted()
                let liveProcessIDs = Array(Set(liveTerminalItems.compactMap(\.processId))).sorted()
                let liveTerminalPayloads = liveTerminalItems.compactMap(\.terminalStdin).map(escapeRaw).joined(separator: ",")
                let readbackRetainedTerminal = readback.items.contains {
                    (($0.terminalStdin ?? "").isEmpty == false)
                }

                print("attempt=\(attempt) bootstrap_thread=\(bootstrap.providerThreadId)")
                print("streamed_snapshots=\(streamedSnapshots.count) approvals=\(approvals.count)")
                print("live_command_items=\(liveCommandItems.count) streamed_terminal_items=\(streamedTerminalItems.count) live_terminal_items=\(liveTerminalItems.count) final_terminal_items=\(finalTerminalItems.count)")
                print("live_terminal_item_ids=\(liveTerminalItemIDs.joined(separator: ",")) final_terminal_item_ids=\(finalTerminalItemIDs.joined(separator: ",")) live_process_ids=\(liveProcessIDs.joined(separator: ","))")
                print("live_terminal_payloads=\(liveTerminalPayloads)")
                print("readback_command_items=\(readbackCommandItems.count) readback_retained_terminal=\(readbackRetainedTerminal)")
                print("contains_finished=\(containsFinished) final_turn=\(transcript.lastTurnStatus ?? "—") readback_turn=\(readback.lastTurnStatus ?? "—")")

                if liveTerminalItems.isEmpty {
                    continue
                }

                guard containsFinished, transcript.lastTurnStatus == "completed" else {
                    fputs("OpenSlopTerminalInteractionProbe failed: live terminal passthrough was seen but the turn did not end with FINISHED/completed.\n", stderr)
                    exit(EXIT_FAILURE)
                }

                guard !finalTerminalItems.isEmpty else {
                    fputs("OpenSlopTerminalInteractionProbe failed: live terminal passthrough never reached the final streamed transcript snapshot.\n", stderr)
                    exit(EXIT_FAILURE)
                }

                guard !streamedTerminalItems.isEmpty else {
                    fputs("OpenSlopTerminalInteractionProbe failed: terminal passthrough appeared only in the terminal snapshot and not in any streamed in-progress snapshot.\n", stderr)
                    exit(EXIT_FAILURE)
                }

                guard liveTerminalItemIDs.count == 1, finalTerminalItemIDs.count == 1, liveTerminalItemIDs == finalTerminalItemIDs else {
                    fputs("OpenSlopTerminalInteractionProbe failed: raw terminal passthrough did not stay attached to one stable command item id.\n", stderr)
                    exit(EXIT_FAILURE)
                }

                guard liveProcessIDs.count == 1 else {
                    fputs("OpenSlopTerminalInteractionProbe failed: raw terminal passthrough did not stay attached to one stable process id.\n", stderr)
                    exit(EXIT_FAILURE)
                }

                guard !readbackRetainedTerminal else {
                    fputs("OpenSlopTerminalInteractionProbe failed: terminal passthrough leaked into ordinary transcript readback instead of staying live-only.\n", stderr)
                    exit(EXIT_FAILURE)
                }

                return
            } catch {
                if isRetryableReadbackFailure(error) {
                    print("attempt=\(attempt) retryable_error=\(error.localizedDescription)")
                    continue
                }

                fputs("OpenSlopTerminalInteractionProbe failed: \(error.localizedDescription)\n", stderr)
                exit(EXIT_FAILURE)
            }
        }

        fputs("OpenSlopTerminalInteractionProbe failed: no live terminalInteraction arrived in 3 attempts.\n", stderr)
        exit(EXIT_FAILURE)
    }

    private static func escapeRaw(_ value: String) -> String {
        var rendered = "\""
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\n":
                rendered += "\\n"
            case "\r":
                rendered += "\\r"
            case "\t":
                rendered += "\\t"
            case "\"":
                rendered += "\\\""
            case "\\":
                rendered += "\\\\"
            default:
                if scalar.value < 0x20 || scalar.value == 0x7F {
                    rendered += String(format: "\\u{%X}", scalar.value)
                } else {
                    rendered.append(String(scalar))
                }
            }
        }
        rendered += "\""
        return rendered
    }

    private static func isRetryableReadbackFailure(_ error: Error) -> Bool {
        let message = error.localizedDescription
        return message.contains("rollout at")
            && message.contains("is empty")
            && message.contains("failed to read thread")
    }
}

private actor StreamRecorder {
    private var snapshotValues: [DaemonCodexTranscript] = []
    private var approvalValues: [DaemonCodexApprovalRequest] = []

    func record(_ snapshot: DaemonCodexTranscript) {
        snapshotValues.append(snapshot)
    }

    func snapshots() -> [DaemonCodexTranscript] {
        snapshotValues
    }

    func recordApproval(_ approval: DaemonCodexApprovalRequest) {
        approvalValues.append(approval)
    }

    func approvals() -> [DaemonCodexApprovalRequest] {
        approvalValues
    }
}
