import Foundation

public struct DaemonGitReviewSnapshot: Codable, Equatable, Sendable {
    public let kind: String
    public let repoRoot: String
    public let branch: String
    public let head: String
    public let isGitRepository: Bool
    public let hasChanges: Bool
    public let statusState: String
    public let selectedPath: String?
    public let changedFiles: [DaemonGitChangedFile]
    public let diffStat: DaemonGitBoundedText
    public let diff: DaemonGitBoundedText
    public let filePreview: DaemonGitFilePreview?
    public let warnings: [String]
}

public struct DaemonGitChangedFile: Codable, Equatable, Identifiable, Sendable {
    public var id: String { path }

    public let path: String
    public let status: String
    public let staged: Bool
    public let unstaged: Bool
    public let untracked: Bool
}

public struct DaemonGitBoundedText: Codable, Equatable, Sendable {
    public let text: String
    public let lineCount: Int
    public let truncated: Bool
}

public struct DaemonGitFilePreview: Codable, Equatable, Sendable {
    public let path: String
    public let text: String
    public let lineCount: Int
    public let truncated: Bool
    public let binary: Bool
}
