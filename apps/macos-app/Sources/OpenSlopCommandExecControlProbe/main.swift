import Darwin
import Foundation
import WorkbenchCore

@main
struct OpenSlopCommandExecControlProbe {
    private static let command = [
        "python3",
        "-u",
        "-c",
        "import sys,time; print('READY', flush=True); data=sys.stdin.readline(); sys.stdout.write(data); sys.stdout.flush(); time.sleep(60)"
    ]

    static func main() async {
        let client = CoreDaemonClient()
        let recorder = OutputRecorder()
        let processId = "openslop-command-exec-control-\(UUID().uuidString)"

        do {
            let pidBefore = try await client.daemonProcessIdentifier()
            let result = try await client.streamCodexCommandWithControl(
                command: command,
                processId: processId
            ) { event in
                await recorder.record(event)
                let joined = await recorder.joinedOutput()
                let writeAlreadySent = await recorder.writeSent
                let terminateAlreadySent = await recorder.terminateSent

                if !writeAlreadySent, joined.contains("READY") {
                    await recorder.markWriteSent()
                    return .write(
                        DaemonCodexCommandExecWriteRequest(
                            processId: processId,
                            deltaBase64: Data("PING\n".utf8).base64EncodedString(),
                            closeStdin: false
                        )
                    )
                }

                if !terminateAlreadySent, joined.contains("PING") {
                    await recorder.markTerminateSent()
                    return .terminate(
                        DaemonCodexCommandExecTerminateRequest(processId: processId)
                    )
                }

                return nil
            }
            let pidAfter = try await client.daemonProcessIdentifier()
            let events = await recorder.events()
            let joinedOutput = await recorder.joinedOutput()
            let writeSent = await recorder.writeSent
            let terminateSent = await recorder.terminateSent
            let uniqueProcessIDs = Array(Set(events.map(\.processId))).sorted()

            print("daemon_pid_before=\(pidBefore) daemon_pid_after=\(pidAfter)")
            print("process_id=\(processId) output_events=\(events.count) unique_process_ids=\(uniqueProcessIDs.joined(separator: ","))")
            print("write_sent=\(writeSent) terminate_sent=\(terminateSent)")
            print("joined_output=\(escape(joinedOutput))")
            print("final_exit=\(result.exitCode) final_stdout=\(escape(result.stdout)) final_stderr=\(escape(result.stderr))")

            guard pidBefore == pidAfter else {
                fputs("OpenSlopCommandExecControlProbe failed: core-daemon pid changed during control lane.\n", stderr)
                exit(EXIT_FAILURE)
            }

            guard uniqueProcessIDs == [processId] else {
                fputs("OpenSlopCommandExecControlProbe failed: output events lost stable processId.\n", stderr)
                exit(EXIT_FAILURE)
            }

            guard writeSent, terminateSent else {
                fputs("OpenSlopCommandExecControlProbe failed: control requests were not both sent.\n", stderr)
                exit(EXIT_FAILURE)
            }

            guard joinedOutput.contains("READY"), joinedOutput.contains("PING") else {
                fputs("OpenSlopCommandExecControlProbe failed: output deltas missed READY or echoed PING.\n", stderr)
                exit(EXIT_FAILURE)
            }

            guard result.stdout.isEmpty, result.stderr.isEmpty else {
                fputs("OpenSlopCommandExecControlProbe failed: streaming control lane duplicated output into final response.\n", stderr)
                exit(EXIT_FAILURE)
            }

            guard result.exitCode != 0 else {
                fputs("OpenSlopCommandExecControlProbe failed: terminate did not produce non-zero exit.\n", stderr)
                exit(EXIT_FAILURE)
            }
        } catch {
            fputs("OpenSlopCommandExecControlProbe failed: \(error.localizedDescription)\n", stderr)
            exit(EXIT_FAILURE)
        }
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

private actor OutputRecorder {
    private(set) var writeSent = false
    private(set) var terminateSent = false
    private var values: [DaemonCodexCommandExecOutputEvent] = []

    func record(_ event: DaemonCodexCommandExecOutputEvent) {
        values.append(event)
    }

    func markWriteSent() {
        writeSent = true
    }

    func markTerminateSent() {
        terminateSent = true
    }

    func events() -> [DaemonCodexCommandExecOutputEvent] {
        values
    }

    func joinedOutput() -> String {
        values
            .compactMap { Data(base64Encoded: $0.deltaBase64) }
            .map { String(decoding: $0, as: UTF8.self) }
            .joined()
    }
}
