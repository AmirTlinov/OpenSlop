import Darwin
import Foundation
import WorkbenchCore

@main
struct OpenSlopExecutionProfileProbe {
    static func main() async {
        do {
            let status = try await CoreDaemonClient().fetchExecutionProfileStatus()
            print("execution_profile_kind=\(status.kind) profiles=\(status.profiles.count)")

            guard let codex = status.profile(for: "Codex") else {
                fail("Codex profile missing")
            }
            print("codex_runtime=\(codex.runtimeLevel) available=\(codex.available) models=\(codex.models.joined(separator: ","))")
            guard codex.runtimeLevel == "live", codex.available else {
                fail("Codex profile is not live")
            }

            guard let claude = status.profile(for: "Claude") else {
                fail("Claude profile missing")
            }
            print("claude_runtime=\(claude.runtimeLevel) available=\(claude.available) modes=\(claude.supportedModes.joined(separator: ","))")
            guard claude.runtimeLevel == "receiptOnly" || claude.runtimeLevel == "unavailable" else {
                fail("Claude profile must be receiptOnly or unavailable, got \(claude.runtimeLevel)")
            }
        } catch {
            fail(error.localizedDescription)
        }
    }
}

private func fail(_ message: String) -> Never {
    fputs("FAIL: \(message)\n", stderr)
    exit(1)
}
