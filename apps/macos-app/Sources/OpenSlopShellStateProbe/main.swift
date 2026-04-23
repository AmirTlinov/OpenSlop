import Darwin
import Foundation
import WorkbenchCore

@main
struct OpenSlopShellStateProbe {
    static func main() {
        let suiteName = "OpenSlopShellStateProbe.\(UUID().uuidString)"

        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fail("failed to create isolated defaults suite.")
        }

        let initial = WorkbenchShellState(
            selectedSessionID: "session-2",
            selectedProvider: "Claude",
            selectedEffort: "Max",
            isInspectorVisible: false
        )

        WorkbenchShellStateStore.save(initial, defaults: defaults)
        let restored = WorkbenchShellStateStore.load(defaults: defaults)

        print("restored_provider=\(restored.selectedProvider)")
        print("restored_effort=\(restored.selectedEffort)")
        print("restored_session=\(restored.selectedSessionID ?? "nil")")
        print("restored_inspector=\(restored.isInspectorVisible)")

        guard restored == initial else {
            fail("restored state does not match persisted shell state.")
        }

        let available = ["session-1", "session-2", "019dbb-shell-live-1", "019dbb-shell-live-2"]
        let preferred = restored.reconciledSelection(
            preferredSessionID: nil,
            availableSessionIDs: available,
            liveSessionPredicate: looksLikeLiveCodexThread
        )
        print("reconciled_preferred=\(preferred ?? "nil")")

        guard preferred == "session-2" else {
            fail("stored selection was not preserved when still available.")
        }

        var missingState = restored
        missingState.selectedSessionID = "missing-session"
        let fallback = missingState.reconciledSelection(
            preferredSessionID: nil,
            availableSessionIDs: available,
            liveSessionPredicate: looksLikeLiveCodexThread
        )
        print("reconciled_fallback=\(fallback ?? "nil")")

        guard fallback == "session-1" else {
            fail("fallback did not choose the first available session when stored selection vanished.")
        }

        let preservedOnEmpty = restored.reconciledSelection(
            preferredSessionID: nil,
            availableSessionIDs: [],
            liveSessionPredicate: looksLikeLiveCodexThread
        )
        print("reconciled_empty=\(preservedOnEmpty ?? "nil")")

        guard preservedOnEmpty == "session-2" else {
            fail("stored selection was not preserved when the session list became unavailable.")
        }

        defaults.removePersistentDomain(forName: suiteName)
    }

    private static func looksLikeLiveCodexThread(_ value: String) -> Bool {
        value.count == 36 && value.filter({ $0 == "-" }).count >= 4
    }

    private static func fail(_ message: String) -> Never {
        fputs("OpenSlopShellStateProbe failed: \(message)\n", stderr)
        exit(EXIT_FAILURE)
    }
}
