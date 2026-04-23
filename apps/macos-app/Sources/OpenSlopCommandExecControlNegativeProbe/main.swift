import Darwin
import Foundation
import WorkbenchCore

@main
struct OpenSlopCommandExecControlNegativeProbe {
    private static let command = DaemonCodexCommandExecProofCommand.boundedInteractiveEcho

    private static let pingBase64 = Data("PING\n".utf8).base64EncodedString()

    static func main() async {
        let client = CoreDaemonClient()
        let processId = "openslop-command-exec-negative-\(UUID().uuidString)"
        let wrongProcessId = "\(processId)-wrong"
        let recorder = WitnessRecorder()

        do {
            let pidBefore = try await client.daemonProcessIdentifier()
            let result = try await client.streamCodexCommandWithControlWitness(
                command: command,
                processId: processId
            ) { event in
                await recorder.record(event)

                switch event {
                case .output:
                    let joined = await recorder.joinedOutput()
                    let wrongWriteSent = await recorder.wrongWriteSent
                    let wrongTerminateSent = await recorder.wrongTerminateSent

                    if !wrongWriteSent, joined.contains("READY") {
                        await recorder.markWrongWriteSent()
                        return .write(
                            DaemonCodexCommandExecWriteRequest(
                                processId: wrongProcessId,
                                deltaBase64: pingBase64,
                                closeStdin: false
                            )
                        )
                    }

                    if !wrongTerminateSent, joined.contains("PING") {
                        await recorder.markWrongTerminateSent()
                        return .terminate(
                            DaemonCodexCommandExecTerminateRequest(processId: wrongProcessId)
                        )
                    }

                    return nil

                case .error(let error):
                    if error.message == "write processId does not match active command/exec" {
                        await recorder.markWrongWriteRejected()
                        if !(await recorder.correctWriteSent) {
                            await recorder.markCorrectWriteSent()
                            return .write(
                                DaemonCodexCommandExecWriteRequest(
                                    processId: processId,
                                    deltaBase64: pingBase64,
                                    closeStdin: false
                                )
                            )
                        }
                    }

                    if error.message == "terminate processId does not match active command/exec" {
                        await recorder.markWrongTerminateRejected()
                        if !(await recorder.correctTerminateSent) {
                            await recorder.markCorrectTerminateSent()
                            return .terminate(
                                DaemonCodexCommandExecTerminateRequest(processId: processId)
                            )
                        }
                    }

                    return nil
                }
            }
            let pidAfter = try await client.daemonProcessIdentifier()
            let outputEvents = await recorder.outputEvents()
            let errorMessages = await recorder.errorMessages()
            let joinedOutput = await recorder.joinedOutput()
            let uniqueProcessIDs = Array(Set(outputEvents.map(\.processId))).sorted()

            print("daemon_pid_before=\(pidBefore) daemon_pid_after=\(pidAfter)")
            print("process_id=\(processId) wrong_process_id=\(wrongProcessId)")
            print("output_events=\(outputEvents.count) control_errors=\(errorMessages.count) unique_process_ids=\(uniqueProcessIDs.joined(separator: ","))")
            print("wrong_write_sent=\(await recorder.wrongWriteSent) wrong_write_rejected=\(await recorder.wrongWriteRejected) correct_write_sent=\(await recorder.correctWriteSent)")
            print("wrong_terminate_sent=\(await recorder.wrongTerminateSent) wrong_terminate_rejected=\(await recorder.wrongTerminateRejected) correct_terminate_sent=\(await recorder.correctTerminateSent)")
            print("error_messages=\(escape(errorMessages.joined(separator: " | ")))")
            print("joined_output=\(escape(joinedOutput))")
            print("final_exit=\(result.exitCode) final_stdout=\(escape(result.stdout)) final_stderr=\(escape(result.stderr))")

            guard pidBefore == pidAfter else {
                fail("core-daemon pid changed during negative control lane.")
            }

            guard uniqueProcessIDs == [processId] else {
                fail("output events lost stable processId.")
            }

            guard await recorder.wrongWriteSent, await recorder.wrongWriteRejected, await recorder.correctWriteSent else {
                fail("write rejection contour did not complete.")
            }

            guard await recorder.wrongTerminateSent, await recorder.wrongTerminateRejected, await recorder.correctTerminateSent else {
                fail("terminate rejection contour did not complete.")
            }

            guard errorMessages == [
                "write processId does not match active command/exec",
                "terminate processId does not match active command/exec",
            ] else {
                fail("unexpected control error sequence.")
            }

            guard joinedOutput.contains("READY"), joinedOutput.contains("PING") else {
                fail("output deltas missed READY or echoed PING.")
            }

            guard result.stdout.isEmpty, result.stderr.isEmpty else {
                fail("streaming control lane duplicated output into final response.")
            }

            guard result.exitCode != 0 else {
                fail("terminate did not produce non-zero exit.")
            }
        } catch {
            fail(error.localizedDescription)
        }
    }

    private static func fail(_ message: String) -> Never {
        fputs("OpenSlopCommandExecControlNegativeProbe failed: \(message)\n", stderr)
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

private actor WitnessRecorder {
    private(set) var wrongWriteSent = false
    private(set) var wrongWriteRejected = false
    private(set) var correctWriteSent = false
    private(set) var wrongTerminateSent = false
    private(set) var wrongTerminateRejected = false
    private(set) var correctTerminateSent = false
    private var outputs: [DaemonCodexCommandExecOutputEvent] = []
    private var errors: [String] = []

    func record(_ event: DaemonCodexCommandExecControlWitnessEvent) {
        switch event {
        case .output(let output):
            outputs.append(output)
        case .error(let error):
            errors.append(error.message)
        }
    }

    func markWrongWriteSent() {
        wrongWriteSent = true
    }

    func markWrongWriteRejected() {
        wrongWriteRejected = true
    }

    func markCorrectWriteSent() {
        correctWriteSent = true
    }

    func markWrongTerminateSent() {
        wrongTerminateSent = true
    }

    func markWrongTerminateRejected() {
        wrongTerminateRejected = true
    }

    func markCorrectTerminateSent() {
        correctTerminateSent = true
    }

    func outputEvents() -> [DaemonCodexCommandExecOutputEvent] {
        outputs
    }

    func errorMessages() -> [String] {
        errors
    }

    func joinedOutput() -> String {
        outputs
            .compactMap { Data(base64Encoded: $0.deltaBase64) }
            .map { String(decoding: $0, as: UTF8.self) }
            .joined()
    }
}
