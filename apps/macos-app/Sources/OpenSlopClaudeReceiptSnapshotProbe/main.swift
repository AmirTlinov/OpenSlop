import Foundation
import WorkbenchCore

@main
struct OpenSlopClaudeReceiptSnapshotProbe {
    static let marker = "OPENSLOP_CLAUDE_DETAIL_OK"

    static func main() async {
        do {
            let client = CoreDaemonClient()
            let inputText = "Reply with exactly \(marker) and nothing else."
            let materialized = try await client.materializeClaudeProofSession(inputText: inputText)
            let snapshot = try await client.fetchClaudeReceiptSnapshot(sessionId: materialized.session.id)

            guard snapshot.kind == "claude_receipt_snapshot" else {
                throw ProbeError("unexpected snapshot kind: \(snapshot.kind)")
            }
            guard snapshot.session == materialized.session else {
                throw ProbeError("snapshot session mismatch: \(snapshot.session) materialized=\(materialized.session)")
            }
            guard snapshot.proof.resultText == marker,
                  snapshot.proof.success,
                  snapshot.proof.resultText == materialized.proof.resultText else {
                throw ProbeError("snapshot proof mismatch: result=\(snapshot.proof.resultText) materialized=\(materialized.proof.resultText)")
            }
            guard snapshot.promptPolicy.maxBytes == DaemonClaudeReceiptPromptPolicy.maxBytes,
                  snapshot.promptPolicy.promptBytes == inputText.utf8.count,
                  snapshot.promptPolicy.bounded else {
                throw ProbeError("snapshot prompt policy mismatch: \(snapshot.promptPolicy)")
            }
            guard snapshot.proof.toolUseCount == 0,
                  snapshot.proof.malformedEventCount == 0,
                  snapshot.proof.sessionPersistence == "disabled",
                  !snapshot.proof.timedOut else {
                throw ProbeError("snapshot violates receipt bounds")
            }
            guard snapshot.lifecycleBoundary.contains("read-only latest receipt"),
                  snapshot.lifecycleBoundary.contains("no Claude dialog") else {
                throw ProbeError("snapshot lifecycle boundary is not explicit: \(snapshot.lifecycleBoundary)")
            }
            guard snapshot.storagePath.contains(".openslop/state/claude-receipt-latest.json") else {
                throw ProbeError("snapshot storage path not repo-local state: \(snapshot.storagePath)")
            }

            print("OpenSlopClaudeReceiptSnapshotProbe ok: session=\(snapshot.session.id) marker=\(snapshot.proof.resultText) promptBytes=\(snapshot.promptPolicy.promptBytes)/\(snapshot.promptPolicy.maxBytes) events=\(snapshot.proof.eventCount)")
        } catch {
            fputs("OpenSlopClaudeReceiptSnapshotProbe failed: \(error.localizedDescription)\n", stderr)
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
