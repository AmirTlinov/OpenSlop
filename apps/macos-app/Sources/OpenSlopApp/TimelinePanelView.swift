import SwiftUI

struct TimelinePanelView: View {
    let project: ProjectSeed?
    let timeline: [TimelineItemSeed]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project?.name ?? "Нет проекта")
                        .font(.title2.weight(.semibold))
                    Text(project?.branch ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Label("S00", systemImage: "flag.fill")
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
}
