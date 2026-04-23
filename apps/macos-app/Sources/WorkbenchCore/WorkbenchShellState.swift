import Foundation

public struct WorkbenchShellState: Codable, Equatable, Sendable {
    public var selectedSessionID: String?
    public var selectedProvider: String
    public var selectedEffort: String
    public var isInspectorVisible: Bool

    public init(
        selectedSessionID: String?,
        selectedProvider: String,
        selectedEffort: String,
        isInspectorVisible: Bool
    ) {
        self.selectedSessionID = selectedSessionID
        self.selectedProvider = selectedProvider
        self.selectedEffort = selectedEffort
        self.isInspectorVisible = isInspectorVisible
    }

    public static let `default` = Self(
        selectedSessionID: nil,
        selectedProvider: "Codex",
        selectedEffort: "High",
        isInspectorVisible: true
    )

    public func reconciledSelection(
        preferredSessionID: String?,
        availableSessionIDs: [String],
        liveSessionPredicate: (String) -> Bool
    ) -> String? {
        if availableSessionIDs.isEmpty {
            return preferredSessionID ?? selectedSessionID
        }

        if let preferredSessionID, availableSessionIDs.contains(preferredSessionID) {
            return preferredSessionID
        }

        if let selectedSessionID, availableSessionIDs.contains(selectedSessionID) {
            return selectedSessionID
        }

        if let preferredLive = availableSessionIDs.last(where: liveSessionPredicate) {
            return preferredLive
        }

        return availableSessionIDs.first
    }

    public func sanitized() -> Self {
        var value = self

        if value.selectedProvider.isEmpty {
            value.selectedProvider = Self.default.selectedProvider
        }

        if value.selectedEffort.isEmpty {
            value.selectedEffort = Self.default.selectedEffort
        }

        return value
    }
}

public enum WorkbenchShellStateStore {
    public static let storageKey = "openslop.workbench.shell-state.v1"

    public static func load(
        defaults: UserDefaults = .standard,
        key: String = storageKey
    ) -> WorkbenchShellState {
        guard
            let data = defaults.data(forKey: key),
            let decoded = try? JSONDecoder().decode(WorkbenchShellState.self, from: data)
        else {
            return .default
        }

        return decoded.sanitized()
    }

    public static func save(
        _ state: WorkbenchShellState,
        defaults: UserDefaults = .standard,
        key: String = storageKey
    ) {
        guard let data = try? JSONEncoder().encode(state) else {
            return
        }

        defaults.set(data, forKey: key)
    }
}
