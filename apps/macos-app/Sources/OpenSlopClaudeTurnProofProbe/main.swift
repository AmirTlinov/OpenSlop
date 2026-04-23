import Foundation
import WorkbenchCore

@main
struct OpenSlopClaudeTurnProofProbe {
    static let marker = "OPENSLOP_CLAUDE_OK"

    static func main() async {
        do {
            let prompt = "Reply with exactly \(marker) and nothing else."
            let proof = try await CoreDaemonClient().fetchClaudeTurnProof(inputText: prompt)

            guard proof.kind == "claude_turn_proof_result" else {
                throw ProbeError("unexpected kind: \(proof.kind)")
            }
            guard proof.bridge.name == "claude-bridge",
                  proof.bridge.version == "0.2.0",
                  proof.bridge.transport == "stdio-json" else {
                throw ProbeError("unexpected bridge summary: \(proof.bridge)")
            }
            guard proof.runtimeAvailable else {
                throw ProbeError("Claude runtime unavailable: \(proof.warnings.joined(separator: "; "))")
            }
            guard proof.success else {
                throw ProbeError("Claude turn proof failed closed: \(proof.warnings.joined(separator: "; ")) result=\(proof.resultText)")
            }
            guard proof.resultText == marker, proof.assistantText == marker else {
                throw ProbeError("Claude did not return exact marker. result=\(proof.resultText) assistant=\(proof.assistantText)")
            }
            guard proof.eventCount > 0,
                  proof.eventTypes.contains("assistant"),
                  proof.eventTypes.contains("result:success") else {
                throw ProbeError("Claude stream did not include expected assistant/result events: \(proof.eventTypes)")
            }
            guard proof.toolUseCount == 0, proof.malformedEventCount == 0 else {
                throw ProbeError("proof must not use tools or malformed stream events: toolUseCount=\(proof.toolUseCount) malformed=\(proof.malformedEventCount)")
            }
            guard proof.sessionPersistence == "disabled", !proof.timedOut else {
                throw ProbeError("proof must be non-persistent and non-timeout: persistence=\(proof.sessionPersistence) timedOut=\(proof.timedOut)")
            }
            guard proof.exitCode == 0 else {
                throw ProbeError("Claude CLI exit code was not zero: \(String(describing: proof.exitCode)) signal=\(String(describing: proof.signal))")
            }

            let costLabel = proof.totalCostUsd.map { String($0) } ?? "unknown"
            print("OpenSlopClaudeTurnProofProbe ok: marker=\(proof.resultText) model=\(proof.model ?? "unknown") events=\(proof.eventCount) cost=\(costLabel)")
        } catch {
            fputs("OpenSlopClaudeTurnProofProbe failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }
}

struct ProbeError: Error, LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}
