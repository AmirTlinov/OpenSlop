import Darwin
import Foundation
import WorkbenchCore

@main
struct OpenSlopCommandExecControlTimeoutProbe {
    private static let command = DaemonCodexCommandExecProofCommand.boundedInteractiveEcho

    private static let pingBase64 = Data("PING\n".utf8).base64EncodedString()

    static func main() async {
        let missingWrite = await runScenario(.missingWrite)
        let missingTerminate = await runScenario(.missingTerminate)

        print("missing_write_error=\(escape(missingWrite.message)) elapsed_ms=\(Int(missingWrite.elapsedMs)) joined_output=\(escape(missingWrite.joinedOutput))")
        print("missing_terminate_error=\(escape(missingTerminate.message)) elapsed_ms=\(Int(missingTerminate.elapsedMs)) joined_output=\(escape(missingTerminate.joinedOutput))")

        guard missingWrite.message.contains("timed out while waiting for command/exec control after 5s") else {
            fail("missing write contour did not fail with 5s timeout.")
        }

        guard missingTerminate.message.contains("timed out while waiting for command/exec control after 5s") else {
            fail("missing terminate contour did not fail with 5s timeout.")
        }

        guard missingWrite.joinedOutput.contains("READY") else {
            fail("missing write contour did not observe READY before timeout.")
        }

        guard missingTerminate.joinedOutput.contains("READY"),
              missingTerminate.joinedOutput.contains("PING") else {
            fail("missing terminate contour did not observe READY and PING before timeout.")
        }

        guard missingWrite.elapsedMs < 12_000 else {
            fail("missing write contour exceeded fail-closed budget.")
        }

        guard missingTerminate.elapsedMs < 12_000 else {
            fail("missing terminate contour exceeded fail-closed budget.")
        }
    }

    private static func runScenario(_ scenario: Scenario) async -> ScenarioResult {
        let client = CoreDaemonClient()
        let processId = "openslop-command-exec-timeout-\(scenario.rawValue)-\(UUID().uuidString)"
        let recorder = OutputRecorder()
        let startedAt = Date()

        do {
            _ = try await client.streamCodexCommandWithControl(
                command: command,
                processId: processId
            ) { outputEvent in
                await recorder.record(outputEvent)

                switch scenario {
                case .missingWrite:
                    return nil
                case .missingTerminate:
                    let joined = await recorder.joinedOutput()
                    if joined.contains("PING") {
                        return nil
                    }
                    if joined.contains("READY") {
                        return .write(
                            DaemonCodexCommandExecWriteRequest(
                                processId: processId,
                                deltaBase64: pingBase64,
                                closeStdin: false
                            )
                        )
                    }
                    return nil
                }
            }
            fail("scenario \(scenario.rawValue) unexpectedly completed.")
        } catch {
            return ScenarioResult(
                message: error.localizedDescription,
                elapsedMs: Date().timeIntervalSince(startedAt) * 1_000,
                joinedOutput: await recorder.joinedOutput()
            )
        }
    }

    private static func fail(_ message: String) -> Never {
        fputs("OpenSlopCommandExecControlTimeoutProbe failed: \(message)\n", stderr)
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

private enum Scenario: String {
    case missingWrite = "missing-write"
    case missingTerminate = "missing-terminate"
}

private struct ScenarioResult {
    let message: String
    let elapsedMs: TimeInterval
    let joinedOutput: String
}

private actor OutputRecorder {
    private var outputs: [DaemonCodexCommandExecOutputEvent] = []

    func record(_ event: DaemonCodexCommandExecOutputEvent) {
        outputs.append(event)
    }

    func joinedOutput() -> String {
        outputs
            .compactMap { Data(base64Encoded: $0.deltaBase64) }
            .map { String(decoding: $0, as: UTF8.self) }
            .joined()
    }
}
