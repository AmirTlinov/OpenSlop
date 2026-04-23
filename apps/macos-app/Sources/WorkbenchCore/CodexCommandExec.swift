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
