import SwiftUI

struct WorkbenchRootView: View {
    let seed: WorkbenchSeed

    @State private var selectedProjectID: ProjectSeed.ID?
    @State private var promptText = "Начать следующий вертикальный слайс"
    @State private var selectedProvider = "Codex"
    @State private var selectedEffort = "High"

    var selectedProject: ProjectSeed? {
        seed.projects.first(where: { $0.id == selectedProjectID }) ?? seed.projects.first
    }

    var body: some View {
        NavigationSplitView {
            SidebarPanelView(
                projects: seed.projects,
                selectedProjectID: $selectedProjectID
            )
        } detail: {
            VStack(spacing: 0) {
                HSplitView {
                    TimelinePanelView(
                        project: selectedProject,
                        timeline: seed.timeline
                    )
                    .frame(minWidth: 720)

                    InspectorPanelView(cards: seed.inspectorCards)
                        .frame(minWidth: 280, idealWidth: 320, maxWidth: 360)
                }

                Divider()

                ComposerBarView(
                    promptText: $promptText,
                    selectedProvider: $selectedProvider,
                    selectedEffort: $selectedEffort
                )
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Picker("Provider", selection: $selectedProvider) {
                        Text("Codex").tag("Codex")
                        Text("Claude").tag("Claude")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)

                    Button("Проверить") { }
                    Button("Запустить") { }
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            selectedProjectID = selectedProjectID ?? seed.projects.first?.id
        }
    }
}
