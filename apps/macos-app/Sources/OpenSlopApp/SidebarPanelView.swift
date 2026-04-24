import SwiftUI
import WorkbenchCore

struct SidebarPanelView: View {
    private enum Queue {
        case inProgress
        case attention
        case receipt
        case done
        case archive
    }

    let sessions: [DaemonSessionSummary]
    @Binding var selectedSessionID: DaemonSessionSummary.ID?
    let loadSummary: String
    let draftProvider: String
    let onStartTask: () -> Void
    let isStartDisabled: Bool

    private var inProgressSessions: [DaemonSessionSummary] {
        sessions.filter { queue(for: $0) == .inProgress }
    }

    private var attentionSessions: [DaemonSessionSummary] {
        sessions.filter { queue(for: $0) == .attention }
    }

    private var receiptSessions: [DaemonSessionSummary] {
        sessions.filter { queue(for: $0) == .receipt }
    }

    private var doneSessions: [DaemonSessionSummary] {
        sessions.filter { queue(for: $0) == .done }
    }

    private var archiveSessions: [DaemonSessionSummary] {
        sessions.filter { queue(for: $0) == .archive }
    }

    private var workspaceNames: [String] {
        Array(Set(sessions.map(\.workspace))).sorted()
    }

    var body: some View {
        List(selection: $selectedSessionID) {
            Section {
                Button(action: onStartTask) {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.pencil")
                            .frame(width: 18)
                            .foregroundStyle(.secondary)
                        Text("Новая задача")
                        Spacer()
                        Text(draftProvider)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.quaternary, in: Capsule())
                    }
                }
                .buttonStyle(.plain)
                .disabled(isStartDisabled)
            }

            if !inProgressSessions.isEmpty {
                Section("В работе") {
                    ForEach(inProgressSessions) { session in
                        sessionRow(session, compact: false)
                    }
                }
            }

            if !attentionSessions.isEmpty {
                Section("Нужно внимание") {
                    ForEach(attentionSessions) { session in
                        sessionRow(session, compact: false)
                    }
                }
            }

            if !receiptSessions.isEmpty {
                Section("Готовые итоги") {
                    ForEach(receiptSessions) { session in
                        sessionRow(session, compact: false)
                    }
                }
            }

            if !doneSessions.isEmpty {
                Section("Готово") {
                    ForEach(doneSessions) { session in
                        sessionRow(session, compact: false)
                    }
                }
            }

            Section("Проекты") {
                if workspaceNames.isEmpty {
                    Label("OpenSlop", systemImage: "folder")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(workspaceNames, id: \.self) { workspace in
                        Label(workspace, systemImage: "folder")
                            .font(.callout)
                    }
                }
            }

            if sessions.isEmpty || !archiveSessions.isEmpty {
                Section("Архив") {
                    if sessions.isEmpty {
                        Text(loadSummary)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(archiveSessions) { session in
                            sessionRow(session, compact: false)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("OpenSlop")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "gearshape")
                Text("Настройки")
                Spacer()
            }
            .font(.callout.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.bar)
        }
    }

    private func sessionRow(_ session: DaemonSessionSummary, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 3 : 4) {
            HStack(spacing: 6) {
                if compact {
                    Image(systemName: "pin")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(session.title)
                    .font(compact ? .callout.weight(.medium) : .headline)
                    .lineLimit(1)
            }
            Text("\(session.workspace) · \(session.provider) · \(humanStatus(session.status))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, compact ? 3 : 4)
        .tag(session.id)
    }

    private func humanStatus(_ status: String) -> String {
        switch status {
        case "needs_first_turn":
            return "готова"
        case "notLoaded":
            return "архив"
        case "in_progress":
            return "в работе"
        default:
            return status.replacingOccurrences(of: "_", with: " ")
        }
    }

    private func queue(for session: DaemonSessionSummary) -> Queue {
        switch session.status {
        case "in_progress", "needs_first_turn":
            return .inProgress
        case "receipt_failed", "failed", "blocked", "dirty":
            return .attention
        case "receipt_proven":
            return .receipt
        case "done", "persisted":
            return .done
        default:
            return .archive
        }
    }
}
