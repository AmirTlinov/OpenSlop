import SwiftUI
import WorkbenchCore

@main
struct OpenSlopApp: App {
    private let initialShellState = WorkbenchShellStateStore.load()

    var body: some Scene {
        WindowGroup("OpenSlop") {
            WorkbenchRootView(initialShellState: initialShellState)
                .frame(
                    minWidth: CGFloat(WorkbenchShellLayoutGeometry.windowWidthRange.lowerBound),
                    minHeight: CGFloat(WorkbenchShellLayoutGeometry.windowHeightRange.lowerBound)
                )
        }
        .defaultSize(
            width: CGFloat(initialShellState.layout.windowWidth),
            height: CGFloat(initialShellState.layout.windowHeight)
        )
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .windowBackgroundDragBehavior(.enabled)
    }
}
