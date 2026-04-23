import Foundation

public struct DaemonCodexCommandExecResult: Codable, Equatable, Sendable {
    public let kind: String
    public let exitCode: Int
    public let stdout: String
    public let stderr: String
}

public enum DaemonCodexCommandExecOutputStream: String, Codable, Equatable, Sendable {
    case stdout
    case stderr
}

public struct DaemonCodexCommandExecOutputEvent: Codable, Equatable, Sendable {
    public let kind: String
    public let processId: String
    public let stream: DaemonCodexCommandExecOutputStream
    public let deltaBase64: String
    public let capReached: Bool
}

public struct DaemonCodexCommandExecWriteRequest: Equatable, Sendable {
    public let processId: String
    public let deltaBase64: String?
    public let closeStdin: Bool

    public init(processId: String, deltaBase64: String?, closeStdin: Bool) {
        self.processId = processId
        self.deltaBase64 = deltaBase64
        self.closeStdin = closeStdin
    }
}

public struct DaemonCodexCommandExecTerminateRequest: Equatable, Sendable {
    public let processId: String

    public init(processId: String) {
        self.processId = processId
    }
}

public enum DaemonCodexCommandExecControlRequest: Equatable, Sendable {
    case write(DaemonCodexCommandExecWriteRequest)
    case terminate(DaemonCodexCommandExecTerminateRequest)
}
