import SwiftUI

@main
struct OpenSlopApp: App {
    var body: some Scene {
        WindowGroup("OpenSlop") {
            WorkbenchRootView()
                .frame(minWidth: 1280, minHeight: 820)
        }
        .defaultSize(width: 1440, height: 900)
    }
}
