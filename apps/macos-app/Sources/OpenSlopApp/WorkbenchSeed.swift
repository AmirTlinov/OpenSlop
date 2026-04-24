import Foundation
import WorkbenchCore

struct TimelineItemSeed: Identifiable, Hashable {
    enum StatusTone: String, Hashable {
        case neutral
        case running
        case success
        case attention
        case unknown
    }

    enum Kind: String {
        case user = "Вы"
        case agent = "Агент"
        case command = "Команда"
        case fileChange = "Файлы"
        case tool = "Действие"
        case verify = "Итог"
    }

    let id: String
    let kind: Kind
    let title: String
    let detail: String
    let secondaryDetail: String?
    let prefersMonospacedDetail: Bool
    let statusLabel: String
    let statusTone: StatusTone
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
        pendingApproval: DaemonCodexApprovalRequest?,
        claudeReceiptSnapshot: DaemonClaudeReceiptSnapshot?,
        claudeReceiptError: String?
    ) -> [TimelineItemSeed] {
        if let pendingApproval {
            return [
                TimelineItemSeed(
                    id: "approval-\(pendingApproval.approvalId)",
                    kind: .tool,
                    title: approvalTitle(for: pendingApproval),
                    detail: approvalHumanDetail(for: pendingApproval),
                    secondaryDetail: approvalDetail(for: pendingApproval),
                    prefersMonospacedDetail: false,
                    statusLabel: "нужно внимание",
                    statusTone: .attention
                ),
            ] + timeline(
                for: session,
                loadSummary: loadSummary,
                transcriptSummary: transcriptSummary,
                transcript: transcript,
                pendingApproval: nil,
                claudeReceiptSnapshot: claudeReceiptSnapshot,
                claudeReceiptError: claudeReceiptError
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
                    prefersMonospacedDetail: prefersMonospacedDetail(for: item),
                    statusLabel: timelineStatusLabel(for: item),
                    statusTone: timelineStatusTone(for: item)
                )
            }
        }

        if let session, session.provider == "Claude", session.status.hasPrefix("receipt_") {
            if let claudeReceiptSnapshot, claudeReceiptSnapshot.session.id == session.id {
                return [
                    TimelineItemSeed(
                        id: "\(session.id)-receipt-detail",
                        kind: .verify,
                        title: claudeReceiptSnapshot.proof.success
                            ? "Готово. Claude receipt сохранён."
                            : "Claude receipt завершился ошибкой",
                        detail: claudeReceiptDetail(for: claudeReceiptSnapshot),
                        secondaryDetail: claudeReceiptSecondaryDetail(for: claudeReceiptSnapshot),
                        prefersMonospacedDetail: false,
                        statusLabel: claudeReceiptSnapshot.proof.success ? "доказано" : "не доказано",
                        statusTone: claudeReceiptSnapshot.proof.success ? .success : .attention
                    ),
                ]
            }

            if let claudeReceiptError, !claudeReceiptError.isEmpty {
                return [
                    TimelineItemSeed(
                        id: "\(session.id)-receipt-detail-unavailable",
                        kind: .verify,
                        title: "Детали Claude receipt недоступны",
                        detail: claudeReceiptError,
                        secondaryDetail: "Read-only session summary still exists. Диалоговый режим остаётся закрыт.",
                        prefersMonospacedDetail: false,
                        statusLabel: "unknown",
                        statusTone: .unknown
                    ),
                ]
            }

            return [
                TimelineItemSeed(
                    id: "\(session.id)-receipt",
                    kind: .verify,
                    title: session.status == "receipt_proven" ? "Готово. Claude receipt есть." : "Claude receipt failed",
                    detail: session.status == "receipt_proven"
                        ? "Daemon-owned receipt snapshot загружается. Это read-only latest receipt."
                        : "Claude receipt path завершился fail-closed. Диалоговый режим остаётся закрыт.",
                    secondaryDetail: "\(session.workspace) · \(session.branch) · \(session.status)",
                    prefersMonospacedDetail: false,
                    statusLabel: session.status == "receipt_proven" ? "доказано" : "не доказано",
                    statusTone: session.status == "receipt_proven" ? .success : .attention
                ),
            ]
        }

        return []
    }

    func timelineEmptyState(
        for session: DaemonSessionSummary?,
        transcript: DaemonCodexTranscript?
    ) -> WorkbenchTimelineEmptyState? {
        WorkbenchTimelineEmptyStateProjector.project(
            selectedSessionTitle: session?.title,
            transcriptItemCount: transcript?.items.count
        )
    }

    func inspectorCards(
        projectionKind: String,
        sessionsCount: Int,
        selectedSession: DaemonSessionSummary?,
        transcript: DaemonCodexTranscript?,
        pendingApproval: DaemonCodexApprovalRequest?,
        claudeReceiptSnapshot: DaemonClaudeReceiptSnapshot?
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

        if let claudeReceiptSnapshot {
            cards.append(
                InspectorCardSeed(
                    id: "claude-receipt-result",
                    title: "Claude receipt",
                    value: shortTimelineValue(claudeReceiptSnapshot.proof.resultText)
                )
            )
            cards.append(
                InspectorCardSeed(
                    id: "claude-receipt-bounds",
                    title: "Receipt bounds",
                    value: "\(claudeReceiptSnapshot.promptPolicy.promptBytes)/\(claudeReceiptSnapshot.promptPolicy.maxBytes) bytes · tools \(claudeReceiptSnapshot.proof.toolUseCount) · malformed \(claudeReceiptSnapshot.proof.malformedEventCount)"
                )
            )
        }

        return cards
    }

    private func claudeReceiptDetail(for snapshot: DaemonClaudeReceiptSnapshot) -> String {
        if snapshot.proof.success {
            return "Готово. Получен реальный Claude receipt. Полный диалоговый режим пока закрыт."
        }

        return "Claude receipt не доказан. Подробности раскрываются в доказательствах."
    }

    private func claudeReceiptProofDetail(for snapshot: DaemonClaudeReceiptSnapshot) -> String {
        let proof = snapshot.proof
        let policy = snapshot.promptPolicy
        let model = proof.model ?? "model unknown"
        let duration = proof.durationMs.map { "\($0) ms" } ?? "duration unknown"
        let cost = proof.totalCostUsd.map { String(format: "$%.6f", $0) } ?? "cost unknown"

        return [
            "Result: \(proof.resultText.isEmpty ? "—" : proof.resultText)",
            "Prompt: \(policy.promptBytes)/\(policy.maxBytes) bytes · bounded=\(policy.bounded ? "yes" : "no")",
            "Events: \(proof.eventCount) · tools \(proof.toolUseCount) · malformed \(proof.malformedEventCount)",
            "Runtime: \(model) · \(duration) · \(cost)",
            "Persistence: \(proof.sessionPersistence) · timedOut=\(proof.timedOut ? "yes" : "no")",
        ].joined(separator: "\n")
    }

    private func claudeReceiptSecondaryDetail(for snapshot: DaemonClaudeReceiptSnapshot) -> String {
        var lines = [
            "\(snapshot.session.workspace) · \(snapshot.session.branch) · \(snapshot.session.status)",
            "Bridge: \(snapshot.proof.bridge.name) \(snapshot.proof.bridge.version) via \(snapshot.proof.bridge.transport)",
            snapshot.lifecycleBoundary,
            claudeReceiptProofDetail(for: snapshot),
        ]

        if !snapshot.proof.warnings.isEmpty {
            lines.append("Warnings: " + snapshot.proof.warnings.joined(separator: " · "))
        }

        return lines.joined(separator: "\n")
    }

    private func shortTimelineValue(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "—"
        }
        if trimmed.count <= 64 {
            return trimmed
        }
        return String(trimmed.prefix(64)) + "…"
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
            return commandTimelineDetail(for: item)
        case "fileChange":
            return item.text.isEmpty
                ? "Файловые изменения ещё материализуются."
                : "Агент подготовил изменения файлов. Список лежит в подробностях."
        default:
            return item.text.isEmpty ? humanTurnStatus(item.turnStatus) : item.text
        }
    }

    private func timelineSecondaryDetail(for item: DaemonCodexTranscriptItem) -> String? {
        switch item.kind {
        case "command":
            var sections: [String] = []
            var meta: [String] = []
            let hasLiveTerminal = (item.processId ?? "").isEmpty == false
                && (item.terminalStdin ?? "").isEmpty == false

            if let processId = item.processId, !processId.isEmpty {
                meta.append("PTY \(processId)")
            }

            if let command = item.command, !command.isEmpty {
                sections.append("command\n\(command)")
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
                if hasLiveTerminal {
                    let tail = DaemonBoundedOutputTailProjector.tail(
                        item.text,
                        policy: .timelineTerminalPreview
                    )
                    sections.append(tail.visibleText)

                    if let summary = tail.summary {
                        sections.append(summary + " Полный live хвост открыт в Inspector.")
                    } else {
                        sections.append("Полный live хвост открыт в Inspector.")
                    }
                } else {
                    sections.append(output)
                }
            }

            return sections.isEmpty ? nil : sections.joined(separator: "\n\n")
        case "fileChange":
            let output = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return output.isEmpty ? nil : output
        default:
            return nil
        }
    }

    private func prefersMonospacedDetail(for item: DaemonCodexTranscriptItem) -> Bool {
        false
    }

    private func timelineStatusLabel(for item: DaemonCodexTranscriptItem) -> String {
        switch item.kind {
        case "user":
            return "запрос"
        case "agent":
            return item.turnStatus == "inProgress" ? "пишет" : "ответ"
        case "command":
            if let exitCode = item.exitCode {
                return exitCode == 0 ? "exit 0" : "exit \(exitCode)"
            }
            return item.turnStatus == "inProgress" ? "в работе" : "команда"
        case "fileChange":
            return item.turnStatus == "inProgress" ? "в работе" : "файлы"
        case "tool":
            return item.turnStatus == "inProgress" ? "в работе" : "действие"
        default:
            return humanTurnStatus(item.turnStatus)
        }
    }

    private func timelineStatusTone(for item: DaemonCodexTranscriptItem) -> TimelineItemSeed.StatusTone {
        if let exitCode = item.exitCode {
            return exitCode == 0 ? .success : .attention
        }

        switch item.turnStatus {
        case "inProgress":
            return .running
        case "completed":
            return item.kind == "command" || item.kind == "fileChange" ? .success : .neutral
        case "failed", "declined":
            return .attention
        default:
            return .unknown
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
            return "Нужно разрешение на команду"
        case "fileChange":
            return "Нужно разрешение на файлы"
        default:
            return "Нужно разрешение"
        }
    }

    private func approvalHumanDetail(for approval: DaemonCodexApprovalRequest) -> String {
        switch approval.kind {
        case "commandExecution":
            return "Агент просит запустить команду. Проверь действие в системном approval-окне."
        case "fileChange":
            return "Агент просит изменить файлы. Проверь действие перед подтверждением."
        default:
            return "Агент ждёт твоего решения. Подробности раскрываются ниже."
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

    private func commandTimelineDetail(for item: DaemonCodexTranscriptItem) -> String {
        let command = item.command
            .map { shortTimelineValue($0.replacingOccurrences(of: "\n", with: " ")) }
            .flatMap { $0.isEmpty ? nil : $0 }

        if let exitCode = item.exitCode {
            if exitCode == 0 {
                return command.map { "Команда завершилась успешно: \($0)" } ?? "Команда завершилась успешно."
            }
            return command.map { "Команда вернула exit \(exitCode): \($0)" } ?? "Команда вернула exit \(exitCode)."
        }

        if item.turnStatus == "inProgress" {
            return command.map { "Выполняется: \($0)" } ?? "Команда выполняется."
        }

        return command.map { "Команда запрошена: \($0)" } ?? "Команда ещё материализуется."
    }

    private func humanTurnStatus(_ status: String) -> String {
        switch status {
        case "inProgress":
            return "Агент работает."
        case "completed":
            return "Ход завершён."
        case "failed":
            return "Ход завершился ошибкой."
        default:
            return status.replacingOccurrences(of: "_", with: " ")
        }
    }
}
