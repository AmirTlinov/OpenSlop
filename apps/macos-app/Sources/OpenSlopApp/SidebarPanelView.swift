import SwiftUI

struct SidebarPanelView: View {
    let projects: [ProjectSeed]
    @Binding var selectedProjectID: ProjectSeed.ID?

    var body: some View {
        List(projects, selection: $selectedProjectID) { project in
            VStack(alignment: .leading, spacing: 4) {
                Text(project.name)
                    .font(.headline)
                Text(project.branch)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .listStyle(.sidebar)
        .navigationTitle("Проекты")
    }
}
