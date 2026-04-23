import Darwin
import Foundation
import WorkbenchCore

@main
struct OpenSlopCommandExecResizeSurfaceProbe {
    static let command = DaemonCodexCommandExecProofCommand.ptyResizeWitness
    static let initialSize = DaemonCodexCommandExecProofCommand.ptyResizeInitialSize
    static let targetSize = DaemonCodexCommandExecProofCommand.ptyResizeTargetSize
    static let finalInput = DaemonCodexCommandExecProofCommand.defaultInteractiveInput

    static func main() async {
        let client = CoreDaemonClient()
        let processId = "openslop-command-exec-resize-surface-\(UUID().uuidString)"
        let recorder = ResizeSurfaceRecorder(command: command, processId: processId)

        do {
            let result = try await client.streamCodexCommandWithControl(
                command: command,
                processId: processId,
                tty: true,
                size: initialSize
            ) { outputEvent in
                let joinedOutput = await recorder.record(outputEvent)

                if joinedOutput.contains("R"), !(await recorder.resizeSent) {
                    await recorder.markResize()
                    return .resize(
                        DaemonCodexCommandExecResizeRequest(
                            processId: processId,
                            size: targetSize
                        )
                    )
                }

                if joinedOutput.contains("W"), !(await recorder.writeAndCloseSent) {
                    await recorder.markWriteAndClose()
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

            let surface = await recorder.complete(result)

            print("process_id=\(surface.processId)")
            print("stage=\(surface.stage.rawValue) exit=\(surface.exitCode.map(String.init) ?? "nil")")
            print("control_trail=\(escape(surface.controlTrail))")
            print("merged_output=\(escape(surface.mergedOutput))")
            print("final_stdout=\(escape(result.stdout)) final_stderr=\(escape(result.stderr))")

            guard surface.stage == .completed else {
                fail("resize surface did not reach completed stage.")
            }

            guard surface.processId == processId else {
                fail("resize surface lost stable processId.")
            }

            guard surface.controlTrail == "[resize 100x40]\nPING\n[close-stdin]\n" else {
                fail("resize surface control trail drifted from expected witness.")
            }

            guard surface.stdout.contains("SIZE1:80x24"),
                  surface.stdout.contains("SIZE2:100x40"),
                  surface.stdout.contains("READ:PING") else {
                fail("resize surface missed SIZE1, SIZE2 or READ markers.")
            }

            guard surface.stderr.isEmpty else {
                fail("resize surface unexpectedly accumulated stderr.")
            }

            guard result.exitCode == 0 else {
                fail("resize surface did not finish with zero exit.")
            }

            guard result.stdout.isEmpty, result.stderr.isEmpty else {
                fail("streaming resize surface duplicated output into final result.")
            }
        } catch {
            fail(error.localizedDescription)
        }
    }

    private static func fail(_ message: String) -> Never {
        fputs("OpenSlopCommandExecResizeSurfaceProbe failed: \(message)\n", stderr)
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

private actor ResizeSurfaceRecorder {
    private var surface: DaemonCodexCommandExecControlSurface
    private(set) var resizeSent = false
    private(set) var writeAndCloseSent = false

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

    func markResize() {
        resizeSent = true
        surface = DaemonCodexCommandExecControlSurfaceProjector.markResize(
            size: OpenSlopCommandExecResizeSurfaceProbe.targetSize,
            on: surface
        )
    }

    func markWriteAndClose() {
        writeAndCloseSent = true
        surface = DaemonCodexCommandExecControlSurfaceProjector.markWriteAndCloseStdin(
            raw: OpenSlopCommandExecResizeSurfaceProbe.finalInput,
            on: surface
        )
    }

    func complete(_ result: DaemonCodexCommandExecResult) -> DaemonCodexCommandExecControlSurface {
        surface = DaemonCodexCommandExecControlSurfaceProjector.complete(result, to: surface)
        return surface
    }
}
