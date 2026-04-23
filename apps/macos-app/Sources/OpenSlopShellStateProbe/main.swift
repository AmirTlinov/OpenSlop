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

        let layout = WorkbenchShellLayoutGeometry(
            windowWidth: 1680,
            windowHeight: 980,
            sidebarWidth: 336,
            inspectorWidth: 388
        )
        let initial = WorkbenchShellState(
            selectedSessionID: "session-2",
            selectedProvider: "Claude",
            selectedEffort: "Max",
            isInspectorVisible: false,
            layout: layout
        )

        WorkbenchShellStateStore.save(initial, defaults: defaults)
        let restored = WorkbenchShellStateStore.load(defaults: defaults)

        print("restored_provider=\(restored.selectedProvider)")
        print("restored_effort=\(restored.selectedEffort)")
        print("restored_session=\(restored.selectedSessionID ?? "nil")")
        print("restored_inspector=\(restored.isInspectorVisible)")
        print("restored_window=\(Int(restored.layout.windowWidth))x\(Int(restored.layout.windowHeight))")
        print("restored_sidebar=\(Int(restored.layout.sidebarWidth))")
        print("restored_inspector_width=\(Int(restored.layout.inspectorWidth))")

        guard restored == initial else {
            fail("restored state does not match persisted shell state.")
        }

        let unsafe = WorkbenchShellState(
            selectedSessionID: "session-2",
            selectedProvider: "Claude",
            selectedEffort: "Max",
            isInspectorVisible: false,
            layout: WorkbenchShellLayoutGeometry(
                windowWidth: 5000,
                windowHeight: 400,
                sidebarWidth: 99,
                inspectorWidth: 999
            )
        )
        WorkbenchShellStateStore.save(unsafe, defaults: defaults)
        let sanitized = WorkbenchShellStateStore.load(defaults: defaults)
        print("sanitized_window=\(Int(sanitized.layout.windowWidth))x\(Int(sanitized.layout.windowHeight))")
        print("sanitized_sidebar=\(Int(sanitized.layout.sidebarWidth))")
        print("sanitized_inspector_width=\(Int(sanitized.layout.inspectorWidth))")

        guard sanitized.layout == WorkbenchShellLayoutGeometry(
            windowWidth: WorkbenchShellLayoutGeometry.windowWidthRange.upperBound,
            windowHeight: WorkbenchShellLayoutGeometry.windowHeightRange.lowerBound,
            sidebarWidth: WorkbenchShellLayoutGeometry.sidebarWidthRange.lowerBound,
            inspectorWidth: WorkbenchShellLayoutGeometry.inspectorWidthRange.upperBound
        ) else {
            fail("layout geometry was not sanitized to safe shell bounds.")
        }

        let legacyJSON = #"{"selectedSessionID":"legacy-session","selectedProvider":"Codex","selectedEffort":"High","isInspectorVisible":true}"#
        defaults.set(Data(legacyJSON.utf8), forKey: WorkbenchShellStateStore.storageKey)
        let legacyRestored = WorkbenchShellStateStore.load(defaults: defaults)
        print("legacy_layout=\(Int(legacyRestored.layout.windowWidth))x\(Int(legacyRestored.layout.windowHeight));sidebar=\(Int(legacyRestored.layout.sidebarWidth));inspector=\(Int(legacyRestored.layout.inspectorWidth))")

        guard legacyRestored.layout == .default else {
            fail("legacy shell state without layout did not load with default geometry.")
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
        value.count == 36 && value.filter { $0 == "-" }.count >= 4
    }

    private static func fail(_ message: String) -> Never {
        fputs("OpenSlopShellStateProbe failed: \(message)\n", stderr)
        exit(EXIT_FAILURE)
    }
}
