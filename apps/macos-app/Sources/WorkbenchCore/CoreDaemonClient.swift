import Foundation

public enum CoreDaemonClientError: LocalizedError {
    case repoRootNotFound
    case daemonBinaryMissing(URL)
    case processLaunchFailed(String)
    case processFailed(code: Int32, stderr: String)
    case emptyResponse
    case decodeFailed(String)
    case invalidResponse(String)
    case requestEncodingFailed(String)

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
            return "Не удалось декодировать ответ core-daemon: \(message)"
        case .invalidResponse(let message):
            return "core-daemon вернул неожиданный ответ: \(message)"
        case .requestEncodingFailed(let message):
            return "Не удалось закодировать запрос к core-daemon: \(message)"
        }
    }
}

public struct CoreDaemonClient: Sendable {
    public init() {}

    public func fetchSessionProjection() async throws -> DaemonSessionProjection {
        try await SharedCoreDaemonTransport.instance.fetchSessionProjection()
    }

    public func startCodexSession() async throws -> DaemonCodexSessionBootstrap {
        try await SharedCoreDaemonTransport.instance.startCodexSession()
    }

    public func fetchCodexTranscript(sessionId: String) async throws -> DaemonCodexTranscript {
        try await SharedCoreDaemonTransport.instance.fetchCodexTranscript(sessionId: sessionId)
    }

    public func submitCodexTurn(sessionId: String, inputText: String) async throws -> DaemonCodexTranscript {
        try await SharedCoreDaemonTransport.instance.submitCodexTurn(sessionId: sessionId, inputText: inputText)
    }

    public func streamCodexTurn(
        sessionId: String,
        inputText: String,
        onSnapshot: @escaping @Sendable (DaemonCodexTranscript) async -> Void,
        onApprovalRequest: @escaping @Sendable (DaemonCodexApprovalRequest) async -> DaemonCodexApprovalDecision
    ) async throws -> DaemonCodexTranscript {
        try await SharedCoreDaemonTransport.instance.streamCodexTurn(
            sessionId: sessionId,
            inputText: inputText,
            onSnapshot: onSnapshot,
            onApprovalRequest: onApprovalRequest
        )
    }

    public func execCodexCommand(
        command: [String],
        cwd: String? = nil
    ) async throws -> DaemonCodexCommandExecResult {
        try await SharedCoreDaemonTransport.instance.execCodexCommand(command: command, cwd: cwd)
    }

    public func streamCodexCommand(
        command: [String],
        cwd: String? = nil,
        processId: String,
        onOutput: @escaping @Sendable (DaemonCodexCommandExecOutputEvent) async -> Void
    ) async throws -> DaemonCodexCommandExecResult {
        try await SharedCoreDaemonTransport.instance.streamCodexCommand(
            command: command,
            cwd: cwd,
            processId: processId,
            onOutput: onOutput
        )
    }

    public func daemonProcessIdentifier() async throws -> Int32 {
        try await SharedCoreDaemonTransport.instance.daemonProcessIdentifier()
    }
}

private enum SharedCoreDaemonTransport {
    static let instance = CoreDaemonTransport()
}

private actor CoreDaemonTransport {
    private var process: Process?
    private var stdinHandle: FileHandle?
    private var stdoutHandle: FileHandle?
    private var stderrHandle: FileHandle?
    private var stdoutBuffer = Data()

    func fetchSessionProjection() throws -> DaemonSessionProjection {
        try ensureRunning()
        return try send(operation: "session-list", expecting: DaemonSessionProjection.self)
    }

    func startCodexSession() throws -> DaemonCodexSessionBootstrap {
        try ensureRunning()
        return try send(operation: "codex-start-session", expecting: DaemonCodexSessionBootstrap.self)
    }

    func fetchCodexTranscript(sessionId: String) throws -> DaemonCodexTranscript {
        try ensureRunning()
        return try send(
            request: CoreDaemonRequest(operation: "codex-read-transcript", sessionId: sessionId),
            expecting: DaemonCodexTranscript.self
        )
    }

    func submitCodexTurn(sessionId: String, inputText: String) throws -> DaemonCodexTranscript {
        try ensureRunning()
        return try send(
            request: CoreDaemonRequest(
                operation: "codex-submit-turn",
                sessionId: sessionId,
                inputText: inputText
            ),
            expecting: DaemonCodexTranscript.self
        )
    }

    func streamCodexTurn(
        sessionId: String,
        inputText: String,
        onSnapshot: @escaping @Sendable (DaemonCodexTranscript) async -> Void,
        onApprovalRequest: @escaping @Sendable (DaemonCodexApprovalRequest) async -> DaemonCodexApprovalDecision
    ) async throws -> DaemonCodexTranscript {
        try ensureRunning()
        try sendRaw(
            request: CoreDaemonRequest(
                operation: "codex-submit-turn-stream",
                sessionId: sessionId,
                inputText: inputText
            )
        )

        while true {
            let response = try readResponseLine()

            if let streamEvent = try? JSONDecoder().decode(DaemonCodexTranscriptStreamEvent.self, from: response),
               streamEvent.kind == "codex_transcript_stream_event"
            {
                await onSnapshot(streamEvent.snapshot)
                continue
            }

            if let approvalEvent = try? JSONDecoder().decode(DaemonCodexApprovalRequestEvent.self, from: response),
               approvalEvent.kind == "codex_approval_request"
            {
                let decision = await onApprovalRequest(approvalEvent.approval)
                try sendRaw(
                    request: CoreDaemonRequest(
                        operation: "codex-resolve-approval",
                        sessionId: approvalEvent.sessionId,
                        approvalId: approvalEvent.approval.approvalId,
                        approvalDecision: decision.rawValue
                    )
                )
                continue
            }

            if let decoded = try? JSONDecoder().decode(DaemonCodexTranscript.self, from: response) {
                return decoded
            }

            if let errorResponse = try? JSONDecoder().decode(CoreDaemonErrorResponse.self, from: response) {
                throw CoreDaemonClientError.invalidResponse(errorResponse.message)
            }

            throw CoreDaemonClientError.decodeFailed(String(decoding: response, as: UTF8.self))
        }
    }

    func execCodexCommand(
        command: [String],
        cwd: String?
    ) throws -> DaemonCodexCommandExecResult {
        try ensureRunning()
        return try send(
            request: CoreDaemonRequest(
                operation: "codex-command-exec",
                command: command,
                cwd: cwd
            ),
            expecting: DaemonCodexCommandExecResult.self
        )
    }

    func streamCodexCommand(
        command: [String],
        cwd: String?,
        processId: String,
        onOutput: @escaping @Sendable (DaemonCodexCommandExecOutputEvent) async -> Void
    ) async throws -> DaemonCodexCommandExecResult {
        try ensureRunning()
        try sendRaw(
            request: CoreDaemonRequest(
                operation: "codex-command-exec-stream",
                command: command,
                cwd: cwd,
                processId: processId,
                streamStdoutStderr: true
            )
        )

        while true {
            let response = try readResponseLine()

            if let outputEvent = try? JSONDecoder().decode(DaemonCodexCommandExecOutputEvent.self, from: response),
               outputEvent.kind == "codex_command_exec_output_event"
            {
                await onOutput(outputEvent)
                continue
            }

            if let decoded = try? JSONDecoder().decode(DaemonCodexCommandExecResult.self, from: response) {
                return decoded
            }

            if let errorResponse = try? JSONDecoder().decode(CoreDaemonErrorResponse.self, from: response) {
                throw CoreDaemonClientError.invalidResponse(errorResponse.message)
            }

            throw CoreDaemonClientError.decodeFailed(String(decoding: response, as: UTF8.self))
        }
    }

    func daemonProcessIdentifier() throws -> Int32 {
        try ensureRunning()
        guard let process else {
            throw CoreDaemonClientError.processLaunchFailed("transport not running")
        }
        return process.processIdentifier
    }

    private func ensureRunning() throws {
        if let process, process.isRunning {
            return
        }

        let repoRoot = try RepoRootLocator.locate()
        let daemonURL = repoRoot.appendingPathComponent("target/debug/core-daemon")
        guard FileManager.default.fileExists(atPath: daemonURL.path) else {
            throw CoreDaemonClientError.daemonBinaryMissing(daemonURL)
        }

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

        do {
            try process.run()
        } catch {
            throw CoreDaemonClientError.processLaunchFailed(error.localizedDescription)
        }

        self.process = process
        self.stdinHandle = stdinPipe.fileHandleForWriting
        self.stdoutHandle = stdoutPipe.fileHandleForReading
        self.stderrHandle = stderrPipe.fileHandleForReading
        self.stdoutBuffer.removeAll(keepingCapacity: true)
    }

    private func send<Response: Decodable>(operation: String, expecting type: Response.Type) throws -> Response {
        try send(request: CoreDaemonRequest(operation: operation), expecting: type)
    }

    private func send<Response: Decodable>(request: CoreDaemonRequest, expecting type: Response.Type) throws -> Response {
        try sendRaw(request: request)
        let response = try readResponseLine()

        if let decoded = try? JSONDecoder().decode(Response.self, from: response) {
            return decoded
        }

        if let errorResponse = try? JSONDecoder().decode(CoreDaemonErrorResponse.self, from: response) {
            throw CoreDaemonClientError.invalidResponse(errorResponse.message)
        }

        throw CoreDaemonClientError.decodeFailed(String(decoding: response, as: UTF8.self))
    }

    private func sendRaw(request: CoreDaemonRequest) throws {
        guard let stdinHandle else {
            throw CoreDaemonClientError.processLaunchFailed("stdin unavailable")
        }

        let encoder = JSONEncoder()
        let payload: Data
        do {
            payload = try encoder.encode(request)
        } catch {
            throw CoreDaemonClientError.requestEncodingFailed(error.localizedDescription)
        }

        var line = payload
        line.append(0x0A)

        do {
            try stdinHandle.write(contentsOf: line)
        } catch {
            throw CoreDaemonClientError.processLaunchFailed(error.localizedDescription)
        }
    }

    private func readResponseLine() throws -> Data {
        guard let stdoutHandle else {
            throw CoreDaemonClientError.processLaunchFailed("stdout unavailable")
        }

        while true {
            if let newlineIndex = stdoutBuffer.firstIndex(of: 0x0A) {
                let line = stdoutBuffer.prefix(upTo: newlineIndex)
                stdoutBuffer.removeSubrange(...newlineIndex)
                if line.isEmpty {
                    continue
                }
                return Data(line)
            }

            let chunk = stdoutHandle.availableData
            if chunk.isEmpty {
                let code = process?.terminationStatus ?? -1
                let stderrText = stderrSnapshot()
                resetProcessHandles()
                throw CoreDaemonClientError.processFailed(code: code, stderr: stderrText)
            }
            stdoutBuffer.append(chunk)
        }
    }

    private func stderrSnapshot() -> String {
        guard let stderrHandle else {
            return "stdio transport closed without stderr output"
        }

        let data = stderrHandle.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return text?.isEmpty == false ? text! : "stdio transport closed without stderr output"
    }

    private func resetProcessHandles() {
        process = nil
        stdinHandle = nil
        stdoutHandle = nil
        stderrHandle = nil
        stdoutBuffer.removeAll(keepingCapacity: false)
    }
}
