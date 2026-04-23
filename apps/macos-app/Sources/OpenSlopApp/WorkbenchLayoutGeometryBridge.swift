import AppKit
import SwiftUI

struct WorkbenchWindowSizeObserver: NSViewRepresentable {
    let onContentSizeChange: (CGSize) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onContentSizeChange: onContentSizeChange)
    }

    func makeNSView(context _: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onContentSizeChange = onContentSizeChange
        DispatchQueue.main.async {
            context.coordinator.attach(to: nsView.window)
        }
    }

    static func dismantleNSView(_: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    @MainActor
    final class Coordinator: NSObject {
        var onContentSizeChange: (CGSize) -> Void
        private weak var observedWindow: NSWindow?
        private var lastReportedSize: CGSize?

        init(onContentSizeChange: @escaping (CGSize) -> Void) {
            self.onContentSizeChange = onContentSizeChange
        }

        func attach(to window: NSWindow?) {
            guard let window else {
                return
            }

            if observedWindow === window {
                reportContentSize(for: window)
                return
            }

            detach()
            observedWindow = window
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowDidResize(_:)),
                name: NSWindow.didResizeNotification,
                object: window
            )
            reportContentSize(for: window)
        }

        func detach() {
            if let observedWindow {
                NotificationCenter.default.removeObserver(
                    self,
                    name: NSWindow.didResizeNotification,
                    object: observedWindow
                )
            }
            observedWindow = nil
            lastReportedSize = nil
        }

        @objc private func windowDidResize(_ notification: Notification) {
            guard let resizedWindow = notification.object as? NSWindow else {
                return
            }

            reportContentSize(for: resizedWindow)
        }

        private func reportContentSize(for window: NSWindow) {
            let contentSize = window.contentView?.bounds.size ?? window.contentLayoutRect.size

            guard contentSize.width.isFinite, contentSize.height.isFinite else {
                return
            }

            guard contentSize.width > 0, contentSize.height > 0 else {
                return
            }

            if let lastReportedSize,
               abs(lastReportedSize.width - contentSize.width) < 1,
               abs(lastReportedSize.height - contentSize.height) < 1
            {
                return
            }

            lastReportedSize = contentSize
            onContentSizeChange(contentSize)
        }
    }
}

private struct WorkbenchLayoutWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        guard next.isFinite, next > 0 else {
            return
        }

        value = next
    }
}

private struct WorkbenchLayoutWidthReader: ViewModifier {
    let onWidthChange: (CGFloat) -> Void

    func body(content: Content) -> some View {
        content
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: WorkbenchLayoutWidthPreferenceKey.self,
                        value: proxy.size.width
                    )
                }
            }
            .onPreferenceChange(WorkbenchLayoutWidthPreferenceKey.self) { width in
                guard width.isFinite, width > 0 else {
                    return
                }

                onWidthChange(width)
            }
    }
}

extension View {
    func onWorkbenchLayoutWidthChange(_ action: @escaping (CGFloat) -> Void) -> some View {
        modifier(WorkbenchLayoutWidthReader(onWidthChange: action))
    }
}
