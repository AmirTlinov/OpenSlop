import Foundation
import WorkbenchCore

@main
struct OpenSlopClaudeReceiptSessionProbe {
    static let marker = "OPENSLOP_CLAUDE_OK"

    static func main() async {
        do {
            let client = CoreDaemonClient()
            let receipt = try await client.materializeClaudeProofSession(
                inputText: "Reply with exactly \(marker) and nothing else."
            )
            let projection = try await client.fetchSessionProjection()

            guard receipt.kind == "claude_proof_session_materialized" else {
                throw ProbeError("unexpected kind: \(receipt.kind)")
            }
            guard receipt.proof.success, receipt.proof.resultText == marker else {
                throw ProbeError("Claude proof did not return exact marker: success=\(receipt.proof.success) result=\(receipt.proof.resultText) warnings=\(receipt.proof.warnings)")
            }
            guard receipt.session.id == "claude-turn-proof-latest",
                  receipt.session.provider == "Claude",
                  receipt.session.status == "receipt_proven" else {
                throw ProbeError("unexpected materialized session: \(receipt.session)")
            }
            guard projection.sessions.contains(where: { session in
                session.id == receipt.session.id && session.provider == "Claude" && session.status == "receipt_proven"
            }) else {
                throw ProbeError("materialized Claude receipt session missing from session_list")
            }
            guard receipt.proof.toolUseCount == 0,
                  receipt.proof.malformedEventCount == 0,
                  receipt.proof.sessionPersistence == "disabled",
                  !receipt.proof.timedOut else {
                throw ProbeError("Claude receipt violated proof bounds")
            }

            print("OpenSlopClaudeReceiptSessionProbe ok: session=\(receipt.session.id) marker=\(receipt.proof.resultText) events=\(receipt.proof.eventCount)")
        } catch {
            fputs("OpenSlopClaudeReceiptSessionProbe failed: \(error.localizedDescription)\n", stderr)
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
