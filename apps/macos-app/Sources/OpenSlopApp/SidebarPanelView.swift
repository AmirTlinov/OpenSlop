import SwiftUI
import WorkbenchCore

struct SidebarPanelView: View {
    let sessions: [DaemonSessionSummary]
    @Binding var selectedSessionID: DaemonSessionSummary.ID?
    let loadSummary: String

    var body: some View {
        List(selection: $selectedSessionID) {
            Section {
                if sessions.isEmpty {
                    Text(loadSummary)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(sessions) { session in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.title)
                                .font(.headline)
                            Text("\(session.workspace) · \(session.provider) · \(session.status)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .tag(session.id)
                    }
                }
            } header: {
                Text("Сессии")
            } footer: {
                Text(loadSummary)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Workbench")
    }
}
