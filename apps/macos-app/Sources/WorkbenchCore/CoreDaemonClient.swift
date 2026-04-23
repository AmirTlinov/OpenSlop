import Foundation

public enum CoreDaemonClientError: LocalizedError {
    case repoRootNotFound
    case daemonBinaryMissing(URL)
    case processLaunchFailed(String)
    case processFailed(code: Int32, stderr: String)
    case emptyResponse
    case decodeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .repoRootNotFound:
            return "Не удалось найти корень репозитория OpenSlop."
        case .daemonBinaryMissing(let url):
            return "Не найден собранный core-daemon: \(url.path). Сначала собери daemon."
        case .processLaunchFailed(let message):
            return "Не удалось запустить core-daemon: \(message)"
        case .processFailed(let code, let stderr):
            return "core-daemon завершился с кодом \(code): \(stderr)"
        case .emptyResponse:
            return "core-daemon вернул пустой ответ."
        case .decodeFailed(let message):
            return "Не удалось декодировать session projection: \(message)"
        }
    }
}

public struct CoreDaemonClient: Sendable {
    public init() {}

    public func fetchSessionProjection() throws -> DaemonSessionProjection {
        let repoRoot = try RepoRootLocator.locate()
        let daemonURL = repoRoot.appendingPathComponent("target/debug/core-daemon")
        guard FileManager.default.fileExists(atPath: daemonURL.path) else {
            throw CoreDaemonClientError.daemonBinaryMissing(daemonURL)
        }

        let process = Process()
        process.executableURL = daemonURL
        process.arguments = ["--query", "session-list"]
        process.currentDirectoryURL = repoRoot

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            throw CoreDaemonClientError.processLaunchFailed(error.localizedDescription)
        }

        process.waitUntilExit()

        let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
        let stderrText = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0 else {
            throw CoreDaemonClientError.processFailed(code: process.terminationStatus, stderr: stderrText)
        }

        guard !stdoutData.isEmpty else {
            throw CoreDaemonClientError.emptyResponse
        }

        do {
            return try JSONDecoder().decode(DaemonSessionProjection.self, from: stdoutData)
        } catch {
            throw CoreDaemonClientError.decodeFailed(error.localizedDescription)
        }
    }
}
