import SwiftUI
import WorkbenchCore

struct SidebarPanelView: View {
    let sessions: [DaemonSessionSummary]
    @Binding var selectedSessionID: DaemonSessionSummary.ID?
    let loadSummary: String

    private var pinnedSessions: [DaemonSessionSummary] {
        Array(sessions.prefix(6))
    }

    private var liveSessions: [DaemonSessionSummary] {
        sessions.filter { $0.id.count == 36 && $0.id.filter { $0 == "-" }.count >= 4 }
    }

    private var workspaceNames: [String] {
        Array(Set(sessions.map(\.workspace))).sorted()
    }

    var body: some View {
        List(selection: $selectedSessionID) {
            Section {
                sidebarAction("Новый чат", systemImage: "square.and.pencil", detail: "Codex start")
                sidebarAction("Поиск", systemImage: "magnifyingglass", detail: "S11")
                sidebarAction("Плагины", systemImage: "circle.grid.2x2", detail: "planned")
                sidebarAction("Автоматизации", systemImage: "clock", detail: "planned")
            }

            Section("Закреплённые") {
                if pinnedSessions.isEmpty {
                    Text("Появятся после загрузки session list")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(pinnedSessions) { session in
                        sessionRow(session, compact: true)
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

            Section("Чаты") {
                if sessions.isEmpty {
                    Text(loadSummary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(liveSessions.isEmpty ? sessions : liveSessions) { session in
                        sessionRow(session, compact: false)
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

    private func sidebarAction(_ title: String, systemImage: String, detail: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .frame(width: 18)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.callout)
            Spacer()
            Text(detail)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(detail == "Codex start" ? .secondary : .tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.quaternary, in: Capsule())
        }
        .foregroundStyle(detail == "Codex start" ? .primary : .secondary)
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
}
