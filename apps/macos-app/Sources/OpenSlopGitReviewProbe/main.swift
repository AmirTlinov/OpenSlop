import Darwin
import Foundation
import WorkbenchCore

@main
struct OpenSlopGitReviewProbe {
    static func main() {
        do {
            let repoRoot = try locateOpenSlopRoot()
            let daemonURL = repoRoot.appendingPathComponent("target/debug/core-daemon")
            guard FileManager.default.fileExists(atPath: daemonURL.path) else {
                fail("core-daemon binary missing at \(daemonURL.path)")
            }

            let dirtyRepo = try makeTemporaryDirectory(prefix: "openslop-git-dirty")
            defer { try? FileManager.default.removeItem(at: dirtyRepo) }
            try createDirtyFixture(at: dirtyRepo)

            let beforeStatus = try gitBytes(repo: dirtyRepo, args: ["status", "--porcelain=v1", "-z"])
            let beforeHead = try gitText(repo: dirtyRepo, args: ["rev-parse", "HEAD"])
            let beforeIndex = try gitIndexBytes(repo: dirtyRepo)

            let allSnapshot: DaemonGitReviewSnapshot = try requestSnapshot(
                daemonURL: daemonURL,
                repoRoot: dirtyRepo,
                gitPath: nil
            )
            let selectedSnapshot: DaemonGitReviewSnapshot = try requestSnapshot(
                daemonURL: daemonURL,
                repoRoot: dirtyRepo,
                gitPath: "src/app.txt"
            )

            let afterIndex = try gitIndexBytes(repo: dirtyRepo)
            let afterStatus = try gitBytes(repo: dirtyRepo, args: ["status", "--porcelain=v1", "-z"])
            let afterHead = try gitText(repo: dirtyRepo, args: ["rev-parse", "HEAD"])

            guard beforeStatus == afterStatus else {
                fail("git status changed after read-only snapshot")
            }
            guard beforeHead == afterHead else {
                fail("HEAD changed after read-only snapshot")
            }
            guard beforeIndex == afterIndex else {
                fail("git index changed after read-only snapshot")
            }

            guard allSnapshot.kind == "git_review_snapshot" else {
                fail("unexpected snapshot kind: \(allSnapshot.kind)")
            }
            guard allSnapshot.isGitRepository else {
                fail("dirty fixture was not recognized as git repository")
            }
            guard allSnapshot.hasChanges, allSnapshot.statusState == "dirty" else {
                fail("dirty fixture was not reported dirty; state=\(allSnapshot.statusState)")
            }
            guard allSnapshot.selectedPath == nil else {
                fail("all snapshot unexpectedly selected path \(allSnapshot.selectedPath ?? "nil")")
            }
            guard !allSnapshot.branch.isEmpty, allSnapshot.head != "unknown" else {
                fail("branch/head were not populated")
            }
            guard allSnapshot.changedFiles.contains(where: { $0.path == "src/app.txt" && $0.unstaged }) else {
                fail("modified tracked file missing from changed files")
            }
            guard allSnapshot.changedFiles.contains(where: { $0.path == "notes.md" && $0.untracked }) else {
                fail("untracked file missing from changed files")
            }
            guard allSnapshot.diff.text.contains("+changed") else {
                fail("tracked diff does not contain modified line")
            }
            guard !allSnapshot.diff.truncated else {
                fail("small fixture diff should not be truncated")
            }
            guard allSnapshot.filePreview == nil else {
                fail("all snapshot should not invent a selected file preview")
            }

            guard selectedSnapshot.selectedPath == "src/app.txt" else {
                fail("selected snapshot did not keep requested path")
            }
            guard selectedSnapshot.diff.text.contains("+changed") else {
                fail("selected diff does not contain modified line")
            }
            guard selectedSnapshot.filePreview?.text.contains("changed") == true else {
                fail("selected file preview does not contain current file contents")
            }

            let noGit = try makeTemporaryDirectory(prefix: "openslop-git-nogit")
            defer { try? FileManager.default.removeItem(at: noGit) }
            let noGitSnapshot: DaemonGitReviewSnapshot = try requestSnapshot(
                daemonURL: daemonURL,
                repoRoot: noGit,
                gitPath: nil
            )
            guard !noGitSnapshot.isGitRepository else {
                fail("non-git directory was reported as git repository")
            }
            guard !noGitSnapshot.hasChanges, noGitSnapshot.statusState == "unavailable" else {
                fail("non-git directory did not report unavailable; state=\(noGitSnapshot.statusState)")
            }
            guard noGitSnapshot.warnings.contains(where: { $0.contains("not a git worktree") }) else {
                fail("non-git snapshot did not carry fail-closed warning")
            }

            print("git_review_kind=\(allSnapshot.kind) branch=\(allSnapshot.branch) head=\(allSnapshot.head) state=\(allSnapshot.statusState)")
            print("git_review_changed=\(allSnapshot.changedFiles.map(\.path).joined(separator: ","))")
            print("git_review_selected=\(selectedSnapshot.selectedPath ?? "nil") preview_lines=\(selectedSnapshot.filePreview?.lineCount ?? 0)")
            print("git_review_no_mutation=true before_status_bytes=\(beforeStatus.count) after_status_bytes=\(afterStatus.count) index_bytes=\(beforeIndex.count)")
            print("git_review_nogit_warning=\(noGitSnapshot.warnings.first ?? "none")")
        } catch {
            fail(error.localizedDescription)
        }
    }

    private static func requestSnapshot(
        daemonURL: URL,
        repoRoot: URL,
        gitPath: String?
    ) throws -> DaemonGitReviewSnapshot {
        let process = Process()
        process.executableURL = daemonURL
        process.arguments = ["--serve-stdio"]
        process.currentDirectoryURL = repoRoot

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        let request = ProbeRequest(operation: "git-review-snapshot", gitPath: gitPath)
        var payload = try JSONEncoder().encode(request)
        payload.append(0x0A)
        try stdinPipe.fileHandleForWriting.write(contentsOf: payload)
        try stdinPipe.fileHandleForWriting.close()

        let stdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let stderr = String(decoding: stderrData, as: UTF8.self)
            throw ProbeError.message("core-daemon exited \(process.terminationStatus): \(stderr)")
        }

        guard let firstLine = String(decoding: stdout, as: UTF8.self)
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
        else {
            throw ProbeError.message("core-daemon returned empty stdout")
        }

        let data = Data(firstLine.utf8)
        if let error = try? JSONDecoder().decode(ProbeErrorResponse.self, from: data), error.kind == "error" {
            throw ProbeError.message(error.message)
        }
        return try JSONDecoder().decode(DaemonGitReviewSnapshot.self, from: data)
    }

    private static func createDirtyFixture(at url: URL) throws {
        try git(repo: url, args: ["init"])
        try git(repo: url, args: ["config", "user.email", "openslop@example.invalid"])
        try git(repo: url, args: ["config", "user.name", "OpenSlop Probe"])

        let src = url.appendingPathComponent("src")
        try FileManager.default.createDirectory(at: src, withIntermediateDirectories: true)
        try "before\n".write(to: src.appendingPathComponent("app.txt"), atomically: true, encoding: .utf8)
        try git(repo: url, args: ["add", "."])
        try git(repo: url, args: ["commit", "-m", "initial"])

        try "before\nchanged\n".write(to: src.appendingPathComponent("app.txt"), atomically: true, encoding: .utf8)
        try "scratch\n".write(to: url.appendingPathComponent("notes.md"), atomically: true, encoding: .utf8)
    }

    private static func locateOpenSlopRoot() throws -> URL {
        var candidate = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while candidate.path != "/" {
            let hasCargo = FileManager.default.fileExists(atPath: candidate.appendingPathComponent("Cargo.toml").path)
            let hasAgents = FileManager.default.fileExists(atPath: candidate.appendingPathComponent("AGENTS.md").path)
            if hasCargo && hasAgents {
                return candidate
            }
            candidate.deleteLastPathComponent()
        }
        throw ProbeError.message("OpenSlop root not found")
    }

    private static func makeTemporaryDirectory(prefix: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func git(repo: URL, args: [String]) throws {
        let output = try runGit(repo: repo, args: args)
        guard output.status == 0 else {
            throw ProbeError.message("git \(args.joined(separator: " ")) failed: \(output.stderr)")
        }
    }

    private static func gitIndexBytes(repo: URL) throws -> Data {
        let indexPath = try gitText(repo: repo, args: ["rev-parse", "--path-format=absolute", "--git-path", "index"])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return try Data(contentsOf: URL(fileURLWithPath: indexPath))
    }

    private static func gitText(repo: URL, args: [String]) throws -> String {
        let output = try runGit(repo: repo, args: args)
        guard output.status == 0 else {
            throw ProbeError.message("git \(args.joined(separator: " ")) failed: \(output.stderr)")
        }
        return output.stdout
    }

    private static func gitBytes(repo: URL, args: [String]) throws -> Data {
        let output = try runGit(repo: repo, args: args)
        guard output.status == 0 else {
            throw ProbeError.message("git \(args.joined(separator: " ")) failed: \(output.stderr)")
        }
        return output.stdoutData
    }

    private static func runGit(repo: URL, args: [String]) throws -> CommandOutput {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.environment = ["GIT_OPTIONAL_LOCKS": "0"]
        process.arguments = ["-C", repo.path] + args
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return CommandOutput(
            status: process.terminationStatus,
            stdoutData: stdoutData,
            stdout: String(decoding: stdoutData, as: UTF8.self),
            stderr: String(decoding: stderrData, as: UTF8.self)
        )
    }

    private static func fail(_ message: String) -> Never {
        fputs("OpenSlopGitReviewProbe failed: \(message)\n", stderr)
        exit(EXIT_FAILURE)
    }
}

private struct ProbeRequest: Codable {
    let operation: String
    let gitPath: String?
}

private struct ProbeErrorResponse: Codable {
    let kind: String
    let message: String
}

private struct CommandOutput {
    let status: Int32
    let stdoutData: Data
    let stdout: String
    let stderr: String
}

private enum ProbeError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case let .message(message): message
        }
    }
}
