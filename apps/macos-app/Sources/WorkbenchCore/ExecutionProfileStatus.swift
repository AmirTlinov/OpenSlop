import Foundation

public struct DaemonExecutionProfileStatus: Codable, Equatable, Sendable {
    public let kind: String
    public let checkedAtUnixMs: UInt64
    public let profiles: [DaemonExecutionProviderProfile]

    public func profile(for provider: String) -> DaemonExecutionProviderProfile? {
        profiles.first { $0.provider == provider }
    }
}

public struct DaemonExecutionProviderProfile: Codable, Equatable, Identifiable, Sendable {
    public var id: String { provider }

    public let provider: String
    public let available: Bool
    public let runtimeLevel: String
    public let defaultModel: String
    public let models: [String]
    public let supportedModes: [String]
    public let warnings: [String]
    public let blockingReason: String?

    public var statusLabel: String {
        switch runtimeLevel {
        case "live":
            return available ? "live" : "unavailable"
        case "receiptOnly":
            return available ? "receipt-only" : "unavailable"
        default:
            return runtimeLevel
        }
    }

    public var isSubmitCapable: Bool {
        available && runtimeLevel == "live"
    }

    public var isReceiptCapable: Bool {
        available && runtimeLevel == "receiptOnly"
    }
}
