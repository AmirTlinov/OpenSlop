import SwiftUI

@main
struct OpenSlopApp: App {
    var body: some Scene {
        WindowGroup("OpenSlop") {
            WorkbenchRootView(seed: .preview)
                .frame(minWidth: 1280, minHeight: 820)
        }
        .defaultSize(width: 1440, height: 900)
    }
}
