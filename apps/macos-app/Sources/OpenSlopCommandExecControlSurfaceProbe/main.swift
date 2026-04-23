import Darwin
import Foundation
import WorkbenchCore

@main
struct OpenSlopCommandExecControlSurfaceProbe {
    private static let command = DaemonCodexCommandExecProofCommand.boundedInteractiveEcho

    static func main() async {
        let client = CoreDaemonClient()
        let processId = "openslop-command-exec-surface-\(UUID().uuidString)"
        let stdinRaw = "PING\n"
        let recorder = ProbeRecorder(command: command, processId: processId)

        do {
            let result = try await client.streamCodexCommandWithControl(
                command: command,
                processId: processId
            ) { outputEvent in
                let joinedOutput = await recorder.record(outputEvent)

                if joinedOutput.contains("READY"), !(await recorder.writeSent) {
                    await recorder.markWriteSent()
                    return .write(
                        DaemonCodexCommandExecWriteRequest(
                            processId: processId,
                            deltaBase64: Data(stdinRaw.utf8).base64EncodedString(),
                            closeStdin: false
                        )
                    )
                }

                if joinedOutput.contains("PING"), !(await recorder.terminateSent) {
                    await recorder.markTerminateSent()
                    return .terminate(
                        DaemonCodexCommandExecTerminateRequest(processId: processId)
                    )
                }

                return nil
            }

            let surface = await recorder.complete(result)

            print("process_id=\(surface.processId)")
            print("stage=\(surface.stage.rawValue) exit=\(surface.exitCode.map(String.init) ?? "nil")")
            print("merged_output=\(escape(surface.mergedOutput))")
            print("stdout=\(escape(surface.stdout)) stderr=\(escape(surface.stderr))")
            print("final_stdout=\(escape(result.stdout)) final_stderr=\(escape(result.stderr))")

            guard surface.stage == .completed else {
                fail("surface did not reach completed stage.")
            }

            guard surface.processId == processId else {
                fail("surface lost stable processId.")
            }

            guard surface.stdout.contains("READY"), surface.stdout.contains("PING") else {
                fail("surface lost READY or echoed PING.")
            }

            guard surface.stderr.isEmpty else {
                fail("surface unexpectedly accumulated stderr.")
            }

            guard result.stdout.isEmpty, result.stderr.isEmpty else {
                fail("streaming control lane duplicated output into final result.")
            }

            guard (surface.exitCode ?? 0) != 0 else {
                fail("terminate did not produce non-zero exit.")
            }
        } catch {
            fail(error.localizedDescription)
        }
    }

    private static func fail(_ message: String) -> Never {
        fputs("OpenSlopCommandExecControlSurfaceProbe failed: \(message)\n", stderr)
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

private actor ProbeRecorder {
    private var surface: DaemonCodexCommandExecControlSurface
    private(set) var writeSent = false
    private(set) var terminateSent = false

    init(command: [String], processId: String) {
        surface = DaemonCodexCommandExecControlSurfaceProjector.start(command: command, processId: processId)
    }

    func record(_ event: DaemonCodexCommandExecOutputEvent) -> String {
        surface = DaemonCodexCommandExecControlSurfaceProjector.recordOutput(
            event,
            nextStage: .awaitingControl,
            to: surface
        )
        return surface.mergedOutput
    }

    func markWriteSent() {
        writeSent = true
        surface = DaemonCodexCommandExecControlSurfaceProjector.markWrite(
            raw: "PING\n",
            on: surface
        )
    }

    func markTerminateSent() {
        terminateSent = true
        surface = DaemonCodexCommandExecControlSurfaceProjector.markTerminate(on: surface)
    }

    func complete(_ result: DaemonCodexCommandExecResult) -> DaemonCodexCommandExecControlSurface {
        surface = DaemonCodexCommandExecControlSurfaceProjector.complete(result, to: surface)
        return surface
    }
}
