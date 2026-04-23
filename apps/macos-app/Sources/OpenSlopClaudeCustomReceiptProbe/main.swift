import Foundation
import WorkbenchCore

@main
struct OpenSlopClaudeCustomReceiptProbe {
    static let marker = "OPENSLOP_CLAUDE_CUSTOM_OK"

    static func main() async {
        do {
            let client = CoreDaemonClient()

            try await assertRejectedPrompt(
                "   ",
                expectedMessage: "missing Claude receipt prompt",
                client: client
            )
            try await assertRejectedPrompt(
                String(repeating: "x", count: DaemonClaudeReceiptPromptPolicy.maxBytes + 1),
                expectedMessage: "Claude receipt prompt too large",
                client: client
            )

            let inputText = "Reply with exactly \(marker) and nothing else."
            let receipt = try await client.materializeClaudeProofSession(inputText: inputText)
            let projection = try await client.fetchSessionProjection()

            guard receipt.kind == "claude_proof_session_materialized" else {
                throw ProbeError("unexpected kind: \(receipt.kind)")
            }
            guard receipt.proof.success, receipt.proof.resultText == marker else {
                throw ProbeError("Claude proof did not return exact custom marker: success=\(receipt.proof.success) result=\(receipt.proof.resultText) warnings=\(receipt.proof.warnings)")
            }
            guard receipt.proof.promptBytes == inputText.utf8.count else {
                throw ProbeError("Claude proof promptBytes mismatch: \(receipt.proof.promptBytes) expected=\(inputText.utf8.count)")
            }
            guard receipt.session.id == "claude-turn-proof-latest",
                  receipt.session.provider == "Claude",
                  receipt.session.status == "receipt_proven",
                  receipt.session.title.contains(marker) else {
                throw ProbeError("unexpected materialized session: \(receipt.session)")
            }
            guard projection.sessions.contains(where: { session in
                session.id == receipt.session.id
                    && session.provider == "Claude"
                    && session.status == "receipt_proven"
                    && session.title.contains(marker)
            }) else {
                throw ProbeError("custom Claude receipt session missing from session_list")
            }
            guard receipt.proof.toolUseCount == 0,
                  receipt.proof.malformedEventCount == 0,
                  receipt.proof.sessionPersistence == "disabled",
                  !receipt.proof.timedOut else {
                throw ProbeError("Claude custom receipt violated proof bounds")
            }

            print("OpenSlopClaudeCustomReceiptProbe ok: session=\(receipt.session.id) marker=\(receipt.proof.resultText) promptBytes=\(receipt.proof.promptBytes) events=\(receipt.proof.eventCount)")
        } catch {
            fputs("OpenSlopClaudeCustomReceiptProbe failed: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    static func assertRejectedPrompt(
        _ prompt: String,
        expectedMessage: String,
        client: CoreDaemonClient
    ) async throws {
        do {
            _ = try await client.materializeClaudeProofSession(inputText: prompt)
            throw ProbeError("prompt unexpectedly accepted: \(expectedMessage)")
        } catch let error as CoreDaemonClientError {
            guard error.localizedDescription.contains(expectedMessage) else {
                throw ProbeError("wrong rejection message: \(error.localizedDescription)")
            }
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
