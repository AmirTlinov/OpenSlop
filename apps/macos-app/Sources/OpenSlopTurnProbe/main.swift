import Darwin
import Foundation
import WorkbenchCore

@main
struct OpenSlopTurnProbe {
    static func main() async {
        let client = CoreDaemonClient()

        do {
            let repoRoot = try RepoRootLocator.locate()
            let bootstrap = try await client.startCodexSession()
            let bootstrapPID = try await client.daemonProcessIdentifier()
            let transcript = try await client.submitCodexTurn(sessionId: bootstrap.session.id, inputText: "Reply with exactly OK.")
            let readback = try await client.fetchCodexTranscript(sessionId: bootstrap.session.id)
            let finalPID = try await client.daemonProcessIdentifier()
            let coldReadback = try readColdTranscript(repoRoot: repoRoot, sessionId: bootstrap.session.id)

            let daemonReused = bootstrapPID == finalPID
            let containsUserPrompt = readback.items.contains { $0.kind == "user" && $0.text.contains("Reply with exactly OK.") }
            let containsAgentOK = readback.items.contains { $0.kind == "agent" && $0.text.trimmingCharacters(in: .whitespacesAndNewlines) == "OK" }
            let coldReadContainsUserPrompt = coldReadback.items.contains { $0.kind == "user" && $0.text.contains("Reply with exactly OK.") }
            let coldReadContainsAgentOK = coldReadback.items.contains { $0.kind == "agent" && $0.text.trimmingCharacters(in: .whitespacesAndNewlines) == "OK" }

            print("bootstrap_thread=\(bootstrap.providerThreadId) transport=\(bootstrap.transport) pid_bootstrap=\(bootstrapPID) pid_final=\(finalPID) reused=\(daemonReused)")
            print("turn_count=\(readback.turnCount) last_turn=\(readback.lastTurnStatus ?? "—") items=\(readback.items.count)")
            print("contains_user_prompt=\(containsUserPrompt) contains_agent_ok=\(containsAgentOK)")
            print("submit_snapshot_items=\(transcript.items.count) readback_items=\(readback.items.count)")
            print("cold_read_status=\(coldReadback.threadStatus) cold_read_turns=\(coldReadback.turnCount) cold_contains_user_prompt=\(coldReadContainsUserPrompt) cold_contains_agent_ok=\(coldReadContainsAgentOK)")

            guard daemonReused else {
                fputs("OpenSlopTurnProbe failed: core-daemon process was not reused across turn round-trip.\n", stderr)
                exit(EXIT_FAILURE)
            }

            guard readback.lastTurnStatus == "completed" else {
                fputs("OpenSlopTurnProbe failed: last turn did not complete.\n", stderr)
                exit(EXIT_FAILURE)
            }

            guard containsUserPrompt, containsAgentOK else {
                fputs("OpenSlopTurnProbe failed: transcript snapshot is missing expected user or agent content.\n", stderr)
                exit(EXIT_FAILURE)
            }

            guard coldReadback.lastTurnStatus == "completed", coldReadContainsUserPrompt, coldReadContainsAgentOK else {
                fputs("OpenSlopTurnProbe failed: cold transcript read did not return the archived completed turn.\n", stderr)
                exit(EXIT_FAILURE)
            }
        } catch {
            fputs("OpenSlopTurnProbe failed: \(error.localizedDescription)\n", stderr)
            exit(EXIT_FAILURE)
        }
    }

    private static func readColdTranscript(repoRoot: URL, sessionId: String) throws -> DaemonCodexTranscript {
        let process = Process()
        process.executableURL = repoRoot.appendingPathComponent("target/debug/core-daemon")
        process.arguments = ["--read-codex-transcript", sessionId, "_"]
        process.currentDirectoryURL = repoRoot

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let errorText = String(decoding: stderr, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            throw ProbeError.coldReadFailed(errorText.isEmpty ? "core-daemon cold read failed" : errorText)
        }

        return try JSONDecoder().decode(DaemonCodexTranscript.self, from: stdout)
    }
}

private enum ProbeError: LocalizedError {
    case coldReadFailed(String)

    var errorDescription: String? {
        switch self {
        case .coldReadFailed(let message):
            return "Не удалось прочитать cold transcript через отдельный core-daemon: \(message)"
        }
    }
}
