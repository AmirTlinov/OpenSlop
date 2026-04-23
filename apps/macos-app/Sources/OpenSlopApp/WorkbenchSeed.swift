import Foundation
import WorkbenchCore

struct TimelineItemSeed: Identifiable, Hashable {
    enum Kind: String {
        case user = "User"
        case agent = "Agent"
        case command = "Command"
        case fileChange = "Files"
        case tool = "Tool"
        case verify = "Verify"
    }

    let id: String
    let kind: Kind
    let title: String
    let detail: String
    let secondaryDetail: String?
    let prefersMonospacedDetail: Bool
}

struct InspectorCardSeed: Identifiable, Hashable {
    let id: String
    let title: String
    let value: String
}

struct WorkbenchSeed {
    static let bootstrap = WorkbenchSeed()

    func timeline(
        for session: DaemonSessionSummary?,
        loadSummary: String,
        transcriptSummary: String,
        transcript: DaemonCodexTranscript?,
        pendingApproval: DaemonCodexApprovalRequest?
    ) -> [TimelineItemSeed] {
        if let pendingApproval {
            return [
                TimelineItemSeed(
                    id: "approval-\(pendingApproval.approvalId)",
                    kind: .tool,
                    title: approvalTitle(for: pendingApproval),
                    detail: approvalDetail(for: pendingApproval),
                    secondaryDetail: nil,
                    prefersMonospacedDetail: true
                ),
            ] + timeline(
                for: session,
                loadSummary: loadSummary,
                transcriptSummary: transcriptSummary,
                transcript: transcript,
                pendingApproval: nil
            )
        }

        if let transcript, !transcript.items.isEmpty {
            return transcript.items.map { item in
                TimelineItemSeed(
                    id: item.id,
                    kind: timelineKind(for: item.kind),
                    title: item.title,
                    detail: timelineDetail(for: item),
                    secondaryDetail: timelineSecondaryDetail(for: item),
                    prefersMonospacedDetail: prefersMonospacedDetail(for: item)
                )
            }
        }

        return [
            TimelineItemSeed(
                id: "projection",
                kind: .agent,
                title: "Session projection loaded from daemon",
                detail: loadSummary,
                secondaryDetail: nil,
                prefersMonospacedDetail: false
            ),
            TimelineItemSeed(
                id: "transcript",
                kind: .tool,
                title: "Read-only transcript lane",
                detail: transcriptSummary,
                secondaryDetail: nil,
                prefersMonospacedDetail: false
            ),
            TimelineItemSeed(
                id: "proof-target",
                kind: .verify,
                title: "S04 first proof target",
                detail: session.map { "Выбрана session: \($0.title) [\($0.provider)]" } ?? "Ожидаем или не можем получить session list.",
                secondaryDetail: nil,
                prefersMonospacedDetail: false
            ),
        ]
    }

    func inspectorCards(
        projectionKind: String,
        sessionsCount: Int,
        selectedSession: DaemonSessionSummary?,
        transcript: DaemonCodexTranscript?,
        pendingApproval: DaemonCodexApprovalRequest?
    ) -> [InspectorCardSeed] {
        var cards = [
            InspectorCardSeed(id: "projection", title: "Projection", value: projectionKind),
            InspectorCardSeed(id: "sessions", title: "Sessions", value: "\(sessionsCount)"),
            InspectorCardSeed(id: "provider", title: "Provider", value: selectedSession?.provider ?? "—"),
            InspectorCardSeed(id: "branch", title: "Branch", value: selectedSession?.branch ?? "—"),
            InspectorCardSeed(id: "thread", title: "Thread", value: transcript?.threadId ?? selectedSession?.id ?? "—"),
            InspectorCardSeed(id: "turns", title: "Turns", value: transcript.map { "\($0.turnCount)" } ?? "0"),
            InspectorCardSeed(id: "last-turn", title: "Last turn", value: transcript?.lastTurnStatus ?? "—"),
        ]

        if let pendingApproval {
            cards.append(
                InspectorCardSeed(
                    id: "approval",
                    title: "Approval",
                    value: approvalTitle(for: pendingApproval)
                )
            )
        }

        return cards
    }

    private func timelineKind(for rawKind: String) -> TimelineItemSeed.Kind {
        switch rawKind {
        case "user":
            return .user
        case "agent":
            return .agent
        case "command":
            return .command
        case "fileChange":
            return .fileChange
        case "tool":
            return .tool
        default:
            return .verify
        }
    }

    private func timelineDetail(for item: DaemonCodexTranscriptItem) -> String {
        switch item.kind {
        case "command":
            return item.command ?? "Команда ещё materializing."
        case "fileChange":
            return item.text.isEmpty ? "Изменения файлов ещё materializing." : item.text
        default:
            return item.text.isEmpty ? item.turnStatus : item.text
        }
    }

    private func timelineSecondaryDetail(for item: DaemonCodexTranscriptItem) -> String? {
        switch item.kind {
        case "command":
            var sections: [String] = []
            var meta: [String] = []

            if let processId = item.processId, !processId.isEmpty {
                meta.append("PTY \(processId)")
            }

            if let exitCode = item.exitCode {
                meta.append("exit \(exitCode)")
            }

            if !meta.isEmpty {
                sections.append(meta.joined(separator: " · "))
            }

            if let terminalStdin = item.terminalStdin, !terminalStdin.isEmpty {
                sections.append("stdin raw " + escapedTerminalStdin(terminalStdin))
            }

            let output = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !output.isEmpty {
                sections.append(output)
            }

            return sections.isEmpty ? nil : sections.joined(separator: "\n\n")
        default:
            return nil
        }
    }

    private func prefersMonospacedDetail(for item: DaemonCodexTranscriptItem) -> Bool {
        switch item.kind {
        case "command", "fileChange":
            return true
        default:
            return false
        }
    }

    private func escapedTerminalStdin(_ value: String) -> String {
        var rendered = "\""
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\n":
                rendered += "\\n"
            case "\r":
                rendered += "\\r"
            case "\t":
                rendered += "\\t"
            case "\"":
                rendered += "\\\""
            case "\\":
                rendered += "\\\\"
            default:
                if scalar.value < 0x20 || scalar.value == 0x7F {
                    rendered += String(format: "\\u{%X}", scalar.value)
                } else {
                    rendered.append(String(scalar))
                }
            }
        }
        rendered += "\""
        return rendered
    }

    private func approvalTitle(for approval: DaemonCodexApprovalRequest) -> String {
        switch approval.kind {
        case "commandExecution":
            return "Approval нужен для команды"
        case "fileChange":
            return "Approval нужен для изменения файлов"
        default:
            return "Approval нужен для действия агента"
        }
    }

    private func approvalDetail(for approval: DaemonCodexApprovalRequest) -> String {
        if let command = approval.command, !command.isEmpty {
            return command
        }
        if let grantRoot = approval.grantRoot, !grantRoot.isEmpty {
            return grantRoot
        }
        if let reason = approval.reason, !reason.isEmpty {
            return reason
        }
        return approval.itemId
    }
}
