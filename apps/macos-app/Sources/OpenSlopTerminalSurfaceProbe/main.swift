import Darwin
import Foundation
import WorkbenchCore

@main
struct OpenSlopTerminalSurfaceProbe {
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
                } onApprovalRequest: { _ in
                    .accept
                }

                let streamedSnapshots = await recorder.snapshots()
                let streamedSurface = streamedSnapshots
                    .compactMap { DaemonCodexTerminalSurfaceProjector.liveSurface(from: $0) }
                    .last
                let finalSurface = DaemonCodexTerminalSurfaceProjector.liveSurface(from: transcript)
                let readback = try await client.fetchCodexTranscript(sessionId: bootstrap.session.id)
                let readbackSurface = DaemonCodexTerminalSurfaceProjector.liveSurface(from: readback)

                print("attempt=\(attempt) bootstrap_thread=\(bootstrap.providerThreadId)")
                print("streamed_surface=\(streamedSurface != nil) final_surface=\(finalSurface != nil) readback_surface=\(readbackSurface != nil)")

                if let finalSurface {
                    print("surface_item_id=\(finalSurface.itemId) process_id=\(finalSurface.processId)")
                    print("surface_stdin=\(escape(finalSurface.terminalStdin))")
                    print("surface_output=\(escape(finalSurface.output))")
                    print("surface_exit=\(finalSurface.exitCode.map(String.init) ?? "nil")")
                }

                guard let streamedSurface else {
                    continue
                }

                guard let finalSurface else {
                    fputs("OpenSlopTerminalSurfaceProbe failed: live terminal pane never materialized from the final streamed transcript.\n", stderr)
                    exit(EXIT_FAILURE)
                }

                guard readbackSurface == nil else {
                    fputs("OpenSlopTerminalSurfaceProbe failed: live terminal pane leaked into ordinary readback.\n", stderr)
                    exit(EXIT_FAILURE)
                }

                guard streamedSurface.itemId == finalSurface.itemId else {
                    fputs("OpenSlopTerminalSurfaceProbe failed: terminal pane did not stay attached to one stable command item.\n", stderr)
                    exit(EXIT_FAILURE)
                }

                guard !finalSurface.processId.isEmpty else {
                    fputs("OpenSlopTerminalSurfaceProbe failed: terminal pane lost processId.\n", stderr)
                    exit(EXIT_FAILURE)
                }

                guard !finalSurface.terminalStdin.isEmpty else {
                    fputs("OpenSlopTerminalSurfaceProbe failed: terminal pane lost raw stdin signal.\n", stderr)
                    exit(EXIT_FAILURE)
                }

                guard !streamedSurface.output.isEmpty else {
                    fputs("OpenSlopTerminalSurfaceProbe failed: streamed terminal pane materialized without any live output.\n", stderr)
                    exit(EXIT_FAILURE)
                }

                guard finalSurface.output.contains("DONE") else {
                    fputs("OpenSlopTerminalSurfaceProbe failed: final terminal pane lost the post-input DONE marker.\n", stderr)
                    exit(EXIT_FAILURE)
                }

                return
            } catch {
                if isRetryableReadbackFailure(error) {
                    print("attempt=\(attempt) retryable_error=\(error.localizedDescription)")
                    continue
                }

                fputs("OpenSlopTerminalSurfaceProbe failed: \(error.localizedDescription)\n", stderr)
                exit(EXIT_FAILURE)
            }
        }

        fputs("OpenSlopTerminalSurfaceProbe failed: no live terminal surface materialized in 3 attempts.\n", stderr)
        exit(EXIT_FAILURE)
    }

    private static func escape(_ value: String) -> String {
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

    func record(_ snapshot: DaemonCodexTranscript) {
        snapshotValues.append(snapshot)
    }

    func snapshots() -> [DaemonCodexTranscript] {
        snapshotValues
    }
}
