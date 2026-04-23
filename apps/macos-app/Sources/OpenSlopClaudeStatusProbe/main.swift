import Foundation
import WorkbenchCore

@main
enum OpenSlopClaudeStatusProbe {
    static func main() async throws {
        let status = try await CoreDaemonClient().fetchClaudeRuntimeStatus()

        guard status.kind == "claude_runtime_status" else {
            throw ProbeError("unexpected kind: \(status.kind)")
        }

        guard status.bridge.name == "claude-bridge", status.bridge.transport == "stdio-json" else {
            throw ProbeError("unexpected bridge summary: \(status.bridge)")
        }

        let localClaudeExists = shellSucceeds("command -v claude >/dev/null 2>&1")
        if localClaudeExists, !status.available {
            throw ProbeError("local claude exists but daemon status is unavailable: \(status.warnings.joined(separator: "; "))")
        }

        if status.available {
            guard status.cliVersion?.contains("Claude Code") == true else {
                throw ProbeError("status available without Claude Code version: \(status.cliVersion ?? "nil")")
            }
            guard status.capabilities.cliPrintJson, status.capabilities.cliStreamJsonOutput else {
                throw ProbeError("expected CLI json/stream-json signals in Claude status")
            }
            guard !status.capabilities.bridgeTurnStreaming,
                  !status.capabilities.bridgeNativeApprovals,
                  !status.capabilities.bridgeTracingHandoff
            else {
                throw ProbeError("S05a must not claim full Claude bridge capabilities")
            }
        } else if status.warnings.isEmpty {
            throw ProbeError("unavailable status must include a warning")
        }

        print("PASS claude-runtime-status available=\(status.available) version=\(status.cliVersion ?? "nil") bridge=\(status.bridge.version)")
    }

    private static func shellSucceeds(_ command: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", command]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}

struct ProbeError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}
