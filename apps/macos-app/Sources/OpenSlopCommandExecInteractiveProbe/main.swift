import Darwin
import Foundation
import WorkbenchCore

@main
struct OpenSlopCommandExecInteractiveProbe {
    private static let command = DaemonCodexCommandExecProofCommand.boundedInteractiveEcho
    private static let firstInput = "PING-1\n"
    private static let secondInput = "PING-2\n"

    static func main() async {
        let client = CoreDaemonClient()
        let processId = "openslop-command-exec-interactive-\(UUID().uuidString)"
        let recorder = InteractiveRecorder(command: command, processId: processId)

        do {
            let result = try await client.streamCodexCommandWithControl(
                command: command,
                processId: processId
            ) { outputEvent in
                let joinedOutput = await recorder.record(outputEvent)

                if joinedOutput.contains("READY"), !(await recorder.firstWriteSent) {
                    await recorder.markWrite(firstInput)
                    return .write(
                        DaemonCodexCommandExecWriteRequest(
                            processId: processId,
                            deltaBase64: Data(firstInput.utf8).base64EncodedString(),
                            closeStdin: false
                        )
                    )
                }

                if joinedOutput.contains("PING-1"), !(await recorder.secondWriteSent) {
                    await recorder.markWrite(secondInput)
                    return .write(
                        DaemonCodexCommandExecWriteRequest(
                            processId: processId,
                            deltaBase64: Data(secondInput.utf8).base64EncodedString(),
                            closeStdin: false
                        )
                    )
                }

                if joinedOutput.contains("PING-2"), !(await recorder.closeSent) {
                    await recorder.markCloseStdin()
                    return .write(
                        DaemonCodexCommandExecWriteRequest(
                            processId: processId,
                            deltaBase64: nil,
                            closeStdin: true
                        )
                    )
                }

                return nil
            }

            let surface = await recorder.complete(result)

            print("process_id=\(surface.processId)")
            print("stage=\(surface.stage.rawValue) exit=\(surface.exitCode.map(String.init) ?? "nil")")
            print("stdin_trail=\(escape(surface.stdinTrail))")
            print("merged_output=\(escape(surface.mergedOutput))")
            print("final_stdout=\(escape(result.stdout)) final_stderr=\(escape(result.stderr))")

            guard surface.stage == .completed else {
                fail("interactive surface did not reach completed stage.")
            }

            guard surface.processId == processId else {
                fail("interactive surface lost stable processId.")
            }

            guard surface.stdinTrail == firstInput + secondInput + "[close-stdin]\n" else {
                fail("stdin trail does not match bounded interactive proof.")
            }

            guard surface.stdout.contains("READY"),
                  surface.stdout.contains("PING-1"),
                  surface.stdout.contains("PING-2"),
                  surface.stdout.contains("CLOSED") else {
                fail("interactive output missed READY, echoed writes or CLOSED marker.")
            }

            guard surface.stderr.isEmpty else {
                fail("interactive surface unexpectedly accumulated stderr.")
            }

            guard result.exitCode == 0 else {
                fail("close stdin path did not finish with zero exit.")
            }

            guard result.stdout.isEmpty, result.stderr.isEmpty else {
                fail("streaming interactive lane duplicated output into final result.")
            }
        } catch {
            fail(error.localizedDescription)
        }
    }

    private static func fail(_ message: String) -> Never {
        fputs("OpenSlopCommandExecInteractiveProbe failed: \(message)\n", stderr)
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

private actor InteractiveRecorder {
    private var surface: DaemonCodexCommandExecControlSurface
    private(set) var firstWriteSent = false
    private(set) var secondWriteSent = false
    private(set) var closeSent = false

    init(command: [String], processId: String) {
        surface = DaemonCodexCommandExecControlSurfaceProjector.start(command: command, processId: processId)
    }

    func record(_ event: DaemonCodexCommandExecOutputEvent) -> String {
        surface = DaemonCodexCommandExecControlSurfaceProjector.recordOutput(
            event,
            nextStage: closeSent ? .running : .awaitingControl,
            to: surface
        )
        return surface.mergedOutput
    }

    func markWrite(_ raw: String) {
        if !firstWriteSent {
            firstWriteSent = true
        } else {
            secondWriteSent = true
        }
        surface = DaemonCodexCommandExecControlSurfaceProjector.markWrite(raw: raw, on: surface)
    }

    func markCloseStdin() {
        closeSent = true
        surface = DaemonCodexCommandExecControlSurfaceProjector.markCloseStdin(on: surface)
    }

    func complete(_ result: DaemonCodexCommandExecResult) -> DaemonCodexCommandExecControlSurface {
        surface = DaemonCodexCommandExecControlSurfaceProjector.complete(result, to: surface)
        return surface
    }
}
