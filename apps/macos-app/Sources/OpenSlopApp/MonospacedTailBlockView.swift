import SwiftUI
import WorkbenchCore

struct MonospacedTailBlockView: View {
    let label: String
    let tail: DaemonBoundedOutputTail
    let emptyPlaceholder: String
    let minHeight: CGFloat
    let idealHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let summary = tail.summary {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            ScrollView {
                Text(renderedText)
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .frame(minHeight: minHeight, idealHeight: idealHeight)
            .background(.background, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var renderedText: String {
        let trimmed = tail.visibleText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? emptyPlaceholder : tail.visibleText
    }
}
