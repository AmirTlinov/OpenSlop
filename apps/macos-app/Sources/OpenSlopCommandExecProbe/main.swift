import Darwin
import Foundation
import WorkbenchCore

@main
struct OpenSlopCommandExecProbe {
    private static let bufferedCommand = [
        "/bin/sh",
        "-lc",
        "printf 'BUFFERED-OUT\\n'; printf 'BUFFERED-ERR\\n' 1>&2"
    ]

    private static let streamingCommand = [
        "/bin/sh",
        "-lc",
        "printf 'STREAM-OUT-1\\n'; printf 'STREAM-ERR-1\\n' 1>&2; sleep 0.2; printf 'STREAM-OUT-2\\n'; printf 'STREAM-ERR-2\\n' 1>&2"
    ]

    static func main() async {
        let client = CoreDaemonClient()
        let recorder = OutputRecorder()
        let processId = "openslop-command-exec-\(UUID().uuidString)"

        do {
            let buffered = try await client.execCodexCommand(command: bufferedCommand)
            let pidAfterBuffered = try await client.daemonProcessIdentifier()
            let streamed = try await client.streamCodexCommand(
                command: streamingCommand,
                processId: processId
            ) { event in
                await recorder.record(event)
            }
            let pidAfterStreaming = try await client.daemonProcessIdentifier()
            let events = await recorder.events()

            let uniqueProcessIDs = Array(Set(events.map(\.processId))).sorted()
            let stdoutJoined = decodeJoined(events: events, stream: .stdout)
            let stderrJoined = decodeJoined(events: events, stream: .stderr)
            let sawStdout = events.contains { $0.stream == .stdout }
            let sawStderr = events.contains { $0.stream == .stderr }

            print("daemon_pid_buffered=\(pidAfterBuffered) daemon_pid_streaming=\(pidAfterStreaming)")
            print("buffered_exit=\(buffered.exitCode) buffered_stdout=\(escape(buffered.stdout)) buffered_stderr=\(escape(buffered.stderr))")
            print("streaming_process_id=\(processId) output_events=\(events.count) unique_process_ids=\(uniqueProcessIDs.joined(separator: ","))")
            print("streamed_exit=\(streamed.exitCode) streamed_stdout=\(escape(streamed.stdout)) streamed_stderr=\(escape(streamed.stderr))")
            print("streamed_stdout_joined=\(escape(stdoutJoined))")
            print("streamed_stderr_joined=\(escape(stderrJoined))")

            guard pidAfterBuffered == pidAfterStreaming else {
                fputs("OpenSlopCommandExecProbe failed: core-daemon process changed during buffered/streaming exec proof.\n", stderr)
                exit(EXIT_FAILURE)
            }

            guard buffered.exitCode == 0 else {
                fputs("OpenSlopCommandExecProbe failed: buffered command/exec exitCode was not zero.\n", stderr)
                exit(EXIT_FAILURE)
            }

            guard buffered.stdout.contains("BUFFERED-OUT"), buffered.stderr.contains("BUFFERED-ERR") else {
                fputs("OpenSlopCommandExecProbe failed: buffered command/exec did not preserve stdout/stderr in final response.\n", stderr)
                exit(EXIT_FAILURE)
            }

            guard streamed.exitCode == 0 else {
                fputs("OpenSlopCommandExecProbe failed: streaming command/exec exitCode was not zero.\n", stderr)
                exit(EXIT_FAILURE)
            }

            guard streamed.stdout.isEmpty, streamed.stderr.isEmpty else {
                fputs("OpenSlopCommandExecProbe failed: streaming command/exec duplicated output into final response.\n", stderr)
                exit(EXIT_FAILURE)
            }

            guard !events.isEmpty else {
                fputs("OpenSlopCommandExecProbe failed: streaming command/exec produced no output events.\n", stderr)
                exit(EXIT_FAILURE)
            }

            guard uniqueProcessIDs == [processId] else {
                fputs("OpenSlopCommandExecProbe failed: streaming output events did not stay attached to one client-supplied processId.\n", stderr)
                exit(EXIT_FAILURE)
            }

            guard sawStdout, sawStderr else {
                fputs("OpenSlopCommandExecProbe failed: streaming output events did not cover both stdout and stderr.\n", stderr)
                exit(EXIT_FAILURE)
            }

            guard stdoutJoined.contains("STREAM-OUT-1"), stdoutJoined.contains("STREAM-OUT-2") else {
                fputs("OpenSlopCommandExecProbe failed: streaming stdout events missed expected content.\n", stderr)
                exit(EXIT_FAILURE)
            }

            guard stderrJoined.contains("STREAM-ERR-1"), stderrJoined.contains("STREAM-ERR-2") else {
                fputs("OpenSlopCommandExecProbe failed: streaming stderr events missed expected content.\n", stderr)
                exit(EXIT_FAILURE)
            }
        } catch {
            fputs("OpenSlopCommandExecProbe failed: \(error.localizedDescription)\n", stderr)
            exit(EXIT_FAILURE)
        }
    }

    private static func decodeJoined(
        events: [DaemonCodexCommandExecOutputEvent],
        stream: DaemonCodexCommandExecOutputStream
    ) -> String {
        events
            .filter { $0.stream == stream }
            .compactMap { event in
                Data(base64Encoded: event.deltaBase64)
            }
            .map { String(decoding: $0, as: UTF8.self) }
            .joined()
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
    private var values: [DaemonCodexCommandExecOutputEvent] = []

    func record(_ event: DaemonCodexCommandExecOutputEvent) {
        values.append(event)
    }

    func events() -> [DaemonCodexCommandExecOutputEvent] {
        values
    }
}
