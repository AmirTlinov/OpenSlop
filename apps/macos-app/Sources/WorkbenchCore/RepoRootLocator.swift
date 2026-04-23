import Foundation

public enum RepoRootLocator {
    public static func locate() throws -> URL {
        if let explicit = ProcessInfo.processInfo.environment["OPEN_SLOP_REPO_ROOT"], !explicit.isEmpty {
            return URL(fileURLWithPath: explicit)
        }

        let fileManager = FileManager.default
        var candidate = URL(fileURLWithPath: #filePath).deletingLastPathComponent()

        while candidate.path != "/" {
            let hasCargo = fileManager.fileExists(atPath: candidate.appendingPathComponent("Cargo.toml").path)
            let hasAgents = fileManager.fileExists(atPath: candidate.appendingPathComponent("AGENTS.md").path)
            if hasCargo && hasAgents {
                return candidate
            }
            candidate.deleteLastPathComponent()
        }

        throw CoreDaemonClientError.repoRootNotFound
    }
}
