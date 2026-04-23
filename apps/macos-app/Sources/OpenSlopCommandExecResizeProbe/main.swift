import Darwin
import Foundation
import WorkbenchCore

@main
struct OpenSlopCommandExecResizeProbe {
    private static let command = DaemonCodexCommandExecProofCommand.ptyResizeWitness
    private static let initialSize = DaemonCodexCommandExecProofCommand.ptyResizeInitialSize
    private static let resizedSize = DaemonCodexCommandExecProofCommand.ptyResizeTargetSize
    private static let finalInput = DaemonCodexCommandExecProofCommand.defaultInteractiveInput

    static func main() async {
        let client = CoreDaemonClient()
        let processId = "openslop-command-exec-resize-\(UUID().uuidString)"
        let recorder = ResizeRecorder()

        do {
            let pidBefore = try await client.daemonProcessIdentifier()
            let result = try await client.streamCodexCommandWithControl(
                command: command,
                processId: processId,
                tty: true,
                size: initialSize
            ) { event in
                await recorder.record(event)
                let joined = await recorder.normalizedOutput()

                if joined.contains("R"), !(await recorder.resizeSent) {
                    await recorder.markResizeSent()
                    return .resize(
                        DaemonCodexCommandExecResizeRequest(
                            processId: processId,
                            size: resizedSize
                        )
                    )
                }

                if joined.contains("W"), !(await recorder.writeSent) {
                    await recorder.markWriteSent()
                    return .write(
                        DaemonCodexCommandExecWriteRequest(
                            processId: processId,
                            deltaBase64: Data(finalInput.utf8).base64EncodedString(),
                            closeStdin: true
                        )
                    )
                }

                return nil
            }
            let pidAfter = try await client.daemonProcessIdentifier()
            let outputEvents = await recorder.outputEvents()
            let uniqueProcessIDs = Array(Set(outputEvents.map(\.processId))).sorted()
            let joinedOutput = await recorder.normalizedOutput()
            let resizeSent = await recorder.resizeSent
            let writeSent = await recorder.writeSent

            print("daemon_pid_before=\(pidBefore) daemon_pid_after=\(pidAfter)")
            print("process_id=\(processId) output_events=\(outputEvents.count) unique_process_ids=\(uniqueProcessIDs.joined(separator: ","))")
            print("tty_initial=\(initialSize.cols)x\(initialSize.rows) tty_resized=\(resizedSize.cols)x\(resizedSize.rows)")
            print("resize_sent=\(resizeSent) write_sent=\(writeSent)")
            print("joined_output=\(escape(joinedOutput))")
            print("final_exit=\(result.exitCode) final_stdout=\(escape(result.stdout)) final_stderr=\(escape(result.stderr))")

            guard pidBefore == pidAfter else {
                fail("core-daemon pid changed during resize proof lane.")
            }

            guard uniqueProcessIDs == [processId] else {
                fail("output events lost stable processId.")
            }

            guard resizeSent, writeSent else {
                fail("resize or follow-up write were not both sent.")
            }

            guard joinedOutput.contains("SIZE1:80x24"),
                  joinedOutput.contains("SIZE2:100x40"),
                  joinedOutput.contains("READ:\(finalInput.trimmingCharacters(in: .whitespacesAndNewlines))") else {
                fail("resize proof missed SIZE1, SIZE2 or READ markers.")
            }

            guard result.exitCode == 0 else {
                fail("resize proof did not exit cleanly.")
            }

            guard result.stdout.isEmpty, result.stderr.isEmpty else {
                fail("streaming resize lane duplicated output into final result.")
            }
        } catch {
            fail(error.localizedDescription)
        }
    }

    private static func fail(_ message: String) -> Never {
        fputs("OpenSlopCommandExecResizeProbe failed: \(message)\n", stderr)
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
}

private actor ResizeRecorder {
    private(set) var resizeSent = false
    private(set) var writeSent = false
    private var values: [DaemonCodexCommandExecOutputEvent] = []

    func record(_ event: DaemonCodexCommandExecOutputEvent) {
        values.append(event)
    }

    func markResizeSent() {
        resizeSent = true
    }

    func markWriteSent() {
        writeSent = true
    }

    func outputEvents() -> [DaemonCodexCommandExecOutputEvent] {
        values
    }

    func normalizedOutput() -> String {
        values
            .compactMap { Data(base64Encoded: $0.deltaBase64) }
            .map { String(decoding: $0, as: UTF8.self) }
            .joined()
            .replacingOccurrences(of: "\r", with: "")
    }
}
