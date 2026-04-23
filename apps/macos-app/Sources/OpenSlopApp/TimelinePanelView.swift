import SwiftUI
import WorkbenchCore

struct TimelinePanelView: View {
    let session: DaemonSessionSummary?
    let loadSummary: String
    let timeline: [TimelineItemSeed]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session?.title ?? "Session list unavailable")
                        .font(.title2.weight(.semibold))
                    Text(headerSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Label("S02", systemImage: "bolt.horizontal.fill")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.quaternary, in: Capsule())
            }
            .padding(20)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(timeline) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.kind.rawValue)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(item.title)
                                .font(.headline)
                            Text(item.detail)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding(20)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var headerSubtitle: String {
        if let session {
            return "\(session.workspace) · \(session.branch) · \(session.provider) · \(session.status)"
        }
        return loadSummary
    }
}
