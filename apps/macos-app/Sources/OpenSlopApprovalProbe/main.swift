import Darwin
import Foundation
import WorkbenchCore

@main
struct OpenSlopApprovalProbe {
    static func main() async {
        let client = CoreDaemonClient()
        let recorder = ApprovalRecorder()

        do {
            let bootstrap = try await client.startCodexSession()
            let transcript = try await client.streamCodexTurn(
                sessionId: bootstrap.session.id,
                inputText: """
                Use the shell to run `python3 -c "print(123)"`.
                If approval is required, request it and continue after approval.
                After the command succeeds, answer with exactly DONE.
                """
            ) { snapshot in
                await recorder.recordSnapshot(snapshot)
            } onApprovalRequest: { approval in
                await recorder.recordApproval(approval)
                return .accept
            }

            let approvals = await recorder.approvals()
            let snapshots = await recorder.snapshots()
            let approvalCommands = approvals.compactMap(\.command).joined(separator: " | ")
            let commandItems = ([transcript] + snapshots).flatMap(\.items).filter { $0.kind == "command" }
            let containsDone = transcript.items.contains {
                $0.kind == "agent" && $0.text.trimmingCharacters(in: .whitespacesAndNewlines) == "DONE"
            }
            let approvalContainsCommand = approvals.contains {
                ($0.command ?? "").contains("python3 -c")
            }
            let transcriptContainsCommand = commandItems.contains {
                ($0.command ?? "").contains("python3 -c")
            }
            let transcriptHasProcessId = commandItems.contains {
                ($0.processId ?? "").isEmpty == false
            }
            let transcriptHasExitCode = commandItems.contains {
                $0.exitCode == 0
            }
            let transcriptProcessIds = commandItems.compactMap(\.processId).joined(separator: ",")
            let transcriptExitCodes = commandItems.compactMap(\.exitCode).map(String.init).joined(separator: ",")
            let sawStreamingProgress = snapshots.contains {
                $0.lastTurnStatus == "inProgress" || $0.threadStatus == "active"
            }
            let approvalKinds = approvals.map(\.kind).joined(separator: ",")
            let finalTurnStatus = transcript.lastTurnStatus ?? "—"

            print("bootstrap_thread=\(bootstrap.providerThreadId)")
            print("approvals_seen=\(approvals.count)")
            print("approval_kinds=\(approvalKinds)")
            print("streamed_snapshots=\(snapshots.count) saw_streaming_progress=\(sawStreamingProgress)")
            print("approval_commands=\(approvalCommands)")
            print("transcript_command_items=\(commandItems.count) transcript_process_ids=\(transcriptProcessIds) transcript_exit_codes=\(transcriptExitCodes)")
            print("approval_contains_command=\(approvalContainsCommand) transcript_contains_command=\(transcriptContainsCommand) transcript_has_process_id=\(transcriptHasProcessId) transcript_has_exit_code=\(transcriptHasExitCode) contains_done=\(containsDone) final_turn=\(finalTurnStatus)")

            guard !approvals.isEmpty else {
                fputs("OpenSlopApprovalProbe failed: no approval request was surfaced to the GUI lane.\n", stderr)
                exit(EXIT_FAILURE)
            }

            guard sawStreamingProgress else {
                fputs("OpenSlopApprovalProbe failed: no streaming transcript progress was observed.\n", stderr)
                exit(EXIT_FAILURE)
            }

            guard approvalKinds.contains("commandExecution") else {
                fputs("OpenSlopApprovalProbe failed: approval kind did not reach commandExecution.\n", stderr)
                exit(EXIT_FAILURE)
            }

            guard approvalContainsCommand,
                  transcriptContainsCommand,
                  transcriptHasProcessId,
                  transcriptHasExitCode,
                  containsDone,
                  transcript.lastTurnStatus == "completed"
            else {
                fputs("OpenSlopApprovalProbe failed: approval metadata, typed command transcript, process linkage, exit code, or final DONE state did not match expectation.\n", stderr)
                exit(EXIT_FAILURE)
            }
        } catch {
            fputs("OpenSlopApprovalProbe failed: \(error.localizedDescription)\n", stderr)
            exit(EXIT_FAILURE)
        }
    }
}

private actor ApprovalRecorder {
    private var approvalValues: [DaemonCodexApprovalRequest] = []
    private var snapshotValues: [DaemonCodexTranscript] = []

    func recordApproval(_ approval: DaemonCodexApprovalRequest) {
        approvalValues.append(approval)
    }

    func approvals() -> [DaemonCodexApprovalRequest] {
        approvalValues
    }

    func recordSnapshot(_ snapshot: DaemonCodexTranscript) {
        snapshotValues.append(snapshot)
    }

    func snapshots() -> [DaemonCodexTranscript] {
        snapshotValues
    }
}
