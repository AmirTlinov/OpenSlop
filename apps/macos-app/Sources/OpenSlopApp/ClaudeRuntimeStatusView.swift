import SwiftUI
import WorkbenchCore

struct ClaudeRuntimeStatusView: View {
    let status: DaemonClaudeRuntimeStatus?
    let errorMessage: String?
    let isLoading: Bool
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Claude Runtime")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(title)
                        .font(.body.weight(.semibold))
                        .lineLimit(2)
                }
                Spacer()
                Button(isLoading ? "…" : "Проверить", action: onRefresh)
                    .disabled(isLoading)
                    .controlSize(.small)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            if let status {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        statusPill(status.available ? "AVAILABLE" : "UNAVAILABLE", isGood: status.available)
                        Text(status.bridge.transport)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                    }

                    Text(status.boundaryLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    runtimeRow("Binary", status.binaryPath ?? "—")
                    runtimeRow("CLI", status.cliVersion ?? "—")
                    runtimeRow("Node", status.nodeVersion ?? "—")

                    Divider()

                    capabilityLine(status)

                    if !status.warnings.isEmpty {
                        Text(status.warnings.joined(separator: "\n"))
                            .font(.caption.monospaced())
                            .foregroundStyle(.orange)
                            .textSelection(.enabled)
                    }
                }
            } else if errorMessage == nil {
                Text(isLoading ? "Проверяем локальный Claude bridge." : "Claude runtime ещё не проверен.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var title: String {
        guard let status else {
            return "Fail-closed status boundary"
        }
        return status.available ? status.versionLabel : "Runtime unavailable"
    }

    private func runtimeRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .textSelection(.enabled)
        }
    }

    private func capabilityLine(_ status: DaemonClaudeRuntimeStatus) -> some View {
        let ready = [
            status.capabilities.cliPrintJson ? "print-json" : nil,
            status.capabilities.cliStreamJsonOutput ? "stream-json" : nil,
            status.capabilities.cliSessionResume ? "resume" : nil,
            status.capabilities.cliMcpConfig ? "mcp-config" : nil,
        ].compactMap { $0 }

        let pending = [
            status.capabilities.bridgeTurnStreaming ? nil : "turn bridge planned",
            status.capabilities.bridgeNativeApprovals ? nil : "native approvals planned",
            status.capabilities.bridgeTracingHandoff ? nil : "tracing planned",
        ].compactMap { $0 }

        return VStack(alignment: .leading, spacing: 4) {
            Text("CLI signals: " + (ready.isEmpty ? "none" : ready.joined(separator: " · ")))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Bridge ceiling: " + pending.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private func statusPill(_ value: String, isGood: Bool) -> some View {
        Text(value)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(isGood ? Color.green : Color.orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary, in: Capsule())
    }
}
