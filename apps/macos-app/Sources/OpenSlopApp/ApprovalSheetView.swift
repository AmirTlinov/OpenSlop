import SwiftUI
import WorkbenchCore

struct ApprovalSheetView: View {
    let approval: DaemonCodexApprovalRequest
    let onApprove: () -> Void
    let onDeny: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(.title2.weight(.semibold))

            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                ApprovalDetailRow(label: "Kind", value: approval.kind)

                if let command = approval.command, !command.isEmpty {
                    ApprovalDetailRow(label: "Command", value: command)
                }

                if let cwd = approval.cwd, !cwd.isEmpty {
                    ApprovalDetailRow(label: "CWD", value: cwd)
                }

                if let grantRoot = approval.grantRoot, !grantRoot.isEmpty {
                    ApprovalDetailRow(label: "Grant root", value: grantRoot)
                }

                if let reason = approval.reason, !reason.isEmpty {
                    ApprovalDetailRow(label: "Reason", value: reason)
                }

                ApprovalDetailRow(label: "Thread", value: approval.threadId)
                ApprovalDetailRow(label: "Turn", value: approval.turnId)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))

            HStack {
                Spacer()

                Button("Отклонить", action: onDeny)
                    .keyboardShortcut(.cancelAction)

                Button("Разрешить", action: onApprove)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 520)
    }

    private var title: String {
        switch approval.kind {
        case "commandExecution":
            return "Разрешить выполнение команды?"
        case "fileChange":
            return "Разрешить изменение файлов?"
        default:
            return "Разрешить действие агента?"
        }
    }

    private var subtitle: String {
        if let command = approval.command, !command.isEmpty {
            return "Codex просит разрешение перед запуском следующей команды."
        }
        if let grantRoot = approval.grantRoot, !grantRoot.isEmpty {
            return "Codex просит разрешение перед изменением файлов под этим корнем."
        }
        return "Codex остановил turn и ждёт явного решения пользователя."
    }
}

private struct ApprovalDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.monospaced())
                .textSelection(.enabled)
        }
    }
}
