import Foundation
import WorkbenchCore

struct TimelineItemSeed: Identifiable, Hashable {
    enum Kind: String {
        case user = "User"
        case agent = "Agent"
        case tool = "Tool"
        case verify = "Verify"
    }

    let id: String
    let kind: Kind
    let title: String
    let detail: String
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
                    detail: approvalDetail(for: pendingApproval)
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
                    detail: item.text.isEmpty ? item.turnStatus : item.text
                )
            }
        }

        return [
            TimelineItemSeed(
                id: "projection",
                kind: .agent,
                title: "Session projection loaded from daemon",
                detail: loadSummary
            ),
            TimelineItemSeed(
                id: "transcript",
                kind: .tool,
                title: "Read-only transcript lane",
                detail: transcriptSummary
            ),
            TimelineItemSeed(
                id: "proof-target",
                kind: .verify,
                title: "S04 first proof target",
                detail: session.map { "Выбрана session: \($0.title) [\($0.provider)]" } ?? "Ожидаем или не можем получить session list."
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
        case "tool":
            return .tool
        default:
            return .verify
        }
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
