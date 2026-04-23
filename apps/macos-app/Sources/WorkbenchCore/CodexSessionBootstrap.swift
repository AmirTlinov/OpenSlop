import Foundation

public struct DaemonCodexSessionBootstrap: Codable, Equatable, Sendable {
    public let kind: String
    public let session: DaemonSessionSummary
    public let providerThreadId: String
    public let transport: String
    public let cliVersion: String
    public let model: String
    public let modelProvider: String
    public let approvalPolicy: String
    public let sandboxMode: String
    public let reasoningEffort: String?
    public let instructionSources: [String]
    public let initialize: DaemonCodexInitializeSummary
    public let capabilities: DaemonCodexCapabilitySnapshot
}

public struct DaemonCodexInitializeSummary: Codable, Equatable, Sendable {
    public let userAgent: String
    public let codexHome: String
    public let platformFamily: String
    public let platformOs: String
    public let suppressedNotificationMethods: [String]
}

public struct DaemonCodexCapabilitySnapshot: Codable, Equatable, Sendable {
    public let initialize: Bool
    public let threadStart: Bool
    public let threadResume: Bool
    public let notificationSuppression: Bool
    public let turnStart: Bool
    public let threadRead: Bool
}
