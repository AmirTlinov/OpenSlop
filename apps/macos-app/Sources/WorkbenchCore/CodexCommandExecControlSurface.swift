import Foundation

public enum DaemonCodexCommandExecControlStage: String, Equatable, Sendable {
    case idle
    case running
    case awaitingWrite
    case awaitingTerminate
    case completed
    case failed
}

public struct DaemonCodexCommandExecControlSurface: Equatable, Sendable {
    public let command: [String]
    public let processId: String
    public let mergedOutput: String
    public let stdout: String
    public let stderr: String
    public let exitCode: Int?
    public let stage: DaemonCodexCommandExecControlStage
    public let lastError: String?

    public init(
        command: [String],
        processId: String,
        mergedOutput: String,
        stdout: String,
        stderr: String,
        exitCode: Int?,
        stage: DaemonCodexCommandExecControlStage,
        lastError: String?
    ) {
        self.command = command
        self.processId = processId
        self.mergedOutput = mergedOutput
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
        self.stage = stage
        self.lastError = lastError
    }
}

public enum DaemonCodexCommandExecControlSurfaceProjector {
    public static func start(command: [String], processId: String) -> DaemonCodexCommandExecControlSurface {
        DaemonCodexCommandExecControlSurface(
            command: command,
            processId: processId,
            mergedOutput: "",
            stdout: "",
            stderr: "",
            exitCode: nil,
            stage: .running,
            lastError: nil
        )
    }

    public static func recordOutput(
        _ event: DaemonCodexCommandExecOutputEvent,
        nextStage: DaemonCodexCommandExecControlStage,
        to surface: DaemonCodexCommandExecControlSurface
    ) -> DaemonCodexCommandExecControlSurface {
        let decoded = decodeBase64Chunk(event.deltaBase64)

        switch event.stream {
        case .stdout:
            return DaemonCodexCommandExecControlSurface(
                command: surface.command,
                processId: surface.processId,
                mergedOutput: surface.mergedOutput + decoded,
                stdout: surface.stdout + decoded,
                stderr: surface.stderr,
                exitCode: surface.exitCode,
                stage: nextStage,
                lastError: surface.lastError
            )
        case .stderr:
            return DaemonCodexCommandExecControlSurface(
                command: surface.command,
                processId: surface.processId,
                mergedOutput: surface.mergedOutput + decoded,
                stdout: surface.stdout,
                stderr: surface.stderr + decoded,
                exitCode: surface.exitCode,
                stage: nextStage,
                lastError: surface.lastError
            )
        }
    }

    public static func setStage(
        _ stage: DaemonCodexCommandExecControlStage,
        for surface: DaemonCodexCommandExecControlSurface
    ) -> DaemonCodexCommandExecControlSurface {
        DaemonCodexCommandExecControlSurface(
            command: surface.command,
            processId: surface.processId,
            mergedOutput: surface.mergedOutput,
            stdout: surface.stdout,
            stderr: surface.stderr,
            exitCode: surface.exitCode,
            stage: stage,
            lastError: surface.lastError
        )
    }

    public static func complete(
        _ result: DaemonCodexCommandExecResult,
        to surface: DaemonCodexCommandExecControlSurface
    ) -> DaemonCodexCommandExecControlSurface {
        DaemonCodexCommandExecControlSurface(
            command: surface.command,
            processId: surface.processId,
            mergedOutput: surface.mergedOutput,
            stdout: surface.stdout,
            stderr: surface.stderr,
            exitCode: result.exitCode,
            stage: .completed,
            lastError: surface.lastError
        )
    }

    public static func fail(
        _ message: String,
        on surface: DaemonCodexCommandExecControlSurface
    ) -> DaemonCodexCommandExecControlSurface {
        DaemonCodexCommandExecControlSurface(
            command: surface.command,
            processId: surface.processId,
            mergedOutput: surface.mergedOutput,
            stdout: surface.stdout,
            stderr: surface.stderr,
            exitCode: surface.exitCode,
            stage: .failed,
            lastError: message
        )
    }

    private static func decodeBase64Chunk(_ value: String) -> String {
        guard let data = Data(base64Encoded: value) else {
            return "[invalid-base64-chunk]"
        }
        return String(decoding: data, as: UTF8.self)
    }
}
