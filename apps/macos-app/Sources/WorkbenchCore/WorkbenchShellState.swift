import Foundation

public struct WorkbenchShellLayoutGeometry: Codable, Equatable, Sendable {
    public static let windowWidthRange: ClosedRange<Double> = 1280 ... 2200
    public static let windowHeightRange: ClosedRange<Double> = 820 ... 1600
    public static let sidebarWidthRange: ClosedRange<Double> = 220 ... 420
    public static let inspectorWidthRange: ClosedRange<Double> = 280 ... 460

    public var windowWidth: Double
    public var windowHeight: Double
    public var sidebarWidth: Double
    public var inspectorWidth: Double

    public init(
        windowWidth: Double,
        windowHeight: Double,
        sidebarWidth: Double,
        inspectorWidth: Double
    ) {
        self.windowWidth = windowWidth
        self.windowHeight = windowHeight
        self.sidebarWidth = sidebarWidth
        self.inspectorWidth = inspectorWidth
    }

    public static let `default` = Self(
        windowWidth: 1440,
        windowHeight: 900,
        sidebarWidth: 280,
        inspectorWidth: 320
    )

    public func sanitized() -> Self {
        Self(
            windowWidth: windowWidth.clamped(to: Self.windowWidthRange),
            windowHeight: windowHeight.clamped(to: Self.windowHeightRange),
            sidebarWidth: sidebarWidth.clamped(to: Self.sidebarWidthRange),
            inspectorWidth: inspectorWidth.clamped(to: Self.inspectorWidthRange)
        )
    }
}

public struct WorkbenchShellState: Codable, Equatable, Sendable {
    public var selectedSessionID: String?
    public var selectedProvider: String
    public var selectedEffort: String
    public var isInspectorVisible: Bool
    public var layout: WorkbenchShellLayoutGeometry

    public init(
        selectedSessionID: String?,
        selectedProvider: String,
        selectedEffort: String,
        isInspectorVisible: Bool,
        layout: WorkbenchShellLayoutGeometry = .default
    ) {
        self.selectedSessionID = selectedSessionID
        self.selectedProvider = selectedProvider
        self.selectedEffort = selectedEffort
        self.isInspectorVisible = isInspectorVisible
        self.layout = layout
    }

    public static let `default` = Self(
        selectedSessionID: nil,
        selectedProvider: "Codex",
        selectedEffort: "High",
        isInspectorVisible: true,
        layout: .default
    )

    private enum CodingKeys: String, CodingKey {
        case selectedSessionID
        case selectedProvider
        case selectedEffort
        case isInspectorVisible
        case layout
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedSessionID = try container.decodeIfPresent(String.self, forKey: .selectedSessionID)
        selectedProvider = try container.decodeIfPresent(String.self, forKey: .selectedProvider) ?? Self.default.selectedProvider
        selectedEffort = try container.decodeIfPresent(String.self, forKey: .selectedEffort) ?? Self.default.selectedEffort
        isInspectorVisible = try container.decodeIfPresent(Bool.self, forKey: .isInspectorVisible) ?? Self.default.isInspectorVisible
        layout = try container.decodeIfPresent(WorkbenchShellLayoutGeometry.self, forKey: .layout) ?? .default
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(selectedSessionID, forKey: .selectedSessionID)
        try container.encode(selectedProvider, forKey: .selectedProvider)
        try container.encode(selectedEffort, forKey: .selectedEffort)
        try container.encode(isInspectorVisible, forKey: .isInspectorVisible)
        try container.encode(layout, forKey: .layout)
    }

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

        value.layout = value.layout.sanitized()

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

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        guard isFinite else {
            return range.lowerBound
        }

        return min(max(self, range.lowerBound), range.upperBound)
    }
}
