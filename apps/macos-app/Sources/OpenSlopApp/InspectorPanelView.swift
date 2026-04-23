import SwiftUI
import WorkbenchCore

struct InspectorPanelView: View {
    let cards: [InspectorCardSeed]
    let terminalSurface: DaemonCodexTerminalSurface?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Inspector")
                .font(.title3.weight(.semibold))
                .padding(20)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(cards) { card in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(card.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(card.value)
                                .font(.body)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
                    }

                    if let terminalSurface {
                        TerminalPaneView(surface: terminalSurface)
                    }
                }
                .padding(16)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
