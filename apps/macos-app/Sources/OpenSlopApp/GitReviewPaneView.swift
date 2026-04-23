import SwiftUI
import WorkbenchCore

struct GitReviewPaneView: View {
    let snapshot: DaemonGitReviewSnapshot?
    let errorMessage: String?
    let isLoading: Bool
    let onRefresh: () -> Void
    let onSelectPath: (String?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Git Review")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(title)
                        .font(.body.weight(.semibold))
                }
                Spacer()
                Button(isLoading ? "…" : "Обновить", action: onRefresh)
                    .disabled(isLoading)
                    .controlSize(.small)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            if let snapshot {
                snapshotBody(snapshot)
            } else if errorMessage == nil {
                Text(isLoading ? "Читаем git snapshot из daemon." : "Git snapshot ещё не загружен.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }

    private var title: String {
        guard let snapshot else {
            return "Read-only repo truth"
        }

        guard snapshot.isGitRepository else {
            return "Not a git worktree"
        }

        return "\(snapshot.branch) @ \(snapshot.head) · \(snapshot.statusState)"
    }

    @ViewBuilder
    private func snapshotBody(_ snapshot: DaemonGitReviewSnapshot) -> some View {
        if !snapshot.isGitRepository {
            warningList(snapshot.warnings)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    statusPill(snapshot.statusState, state: snapshot.statusState)
                    Text("\(snapshot.changedFiles.count) changed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    if snapshot.selectedPath != nil {
                        Button("All diff") {
                            onSelectPath(nil)
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                    }
                }

                changedFiles(snapshot)
                boundedTextBlock(title: diffTitle(snapshot), bounded: snapshot.diff, emptyText: emptyDiffText(snapshot))
                filePreview(snapshot.filePreview, selectedPath: snapshot.selectedPath)
                warningList(snapshot.warnings)
            }
        }
    }

    private func changedFiles(_ snapshot: DaemonGitReviewSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Changed files")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if snapshot.changedFiles.isEmpty {
                Text(snapshot.statusState == "clean" ? "Worktree clean." : "Git status unavailable. See warnings below.")
                    .font(.caption)
                    .foregroundStyle(snapshot.statusState == "clean" ? Color.secondary : Color.orange)
            } else {
                ForEach(snapshot.changedFiles) { file in
                    Button {
                        onSelectPath(file.path)
                    } label: {
                        HStack(spacing: 8) {
                            Text(file.status.trimmingCharacters(in: .whitespaces).isEmpty ? "·" : file.status)
                                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                                .frame(width: 28, alignment: .center)
                                .padding(.vertical, 3)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                            Text(file.path)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            if file.untracked {
                                Text("new")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                        .background(
                            file.path == snapshot.selectedPath
                                ? Color.accentColor.opacity(0.12)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func boundedTextBlock(
        title: String,
        bounded: DaemonGitBoundedText,
        emptyText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if bounded.truncated {
                    Text("truncated · \(bounded.lineCount) lines")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }

            if bounded.text.isEmpty {
                Text(emptyText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(bounded.text)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    @ViewBuilder
    private func filePreview(_ preview: DaemonGitFilePreview?, selectedPath: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("File preview")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let preview, preview.truncated {
                    Text("truncated · \(preview.lineCount) lines")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }

            if let selectedPath {
                if let preview {
                    if preview.binary {
                        Text("Binary file: \(preview.path)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(preview.text.isEmpty ? "Empty file." : preview.text)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                        }
                        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                    }
                } else {
                    Text("Preview unavailable for \(selectedPath). Возможно, файл удалён или недоступен.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            } else {
                Text("Выбери файл выше, чтобы открыть bounded preview.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func warningList(_ warnings: [String]) -> some View {
        if !warnings.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(warnings, id: \.self) { warning in
                    Text("⚠︎ \(warning)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func statusPill(_ text: String, state: String) -> some View {
        let color: Color = switch state {
        case "clean": .green
        case "dirty": .orange
        default: .red
        }

        return Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func diffTitle(_ snapshot: DaemonGitReviewSnapshot) -> String {
        if let path = snapshot.selectedPath {
            return "Diff · \(path)"
        }
        return "Diff"
    }

    private func emptyDiffText(_ snapshot: DaemonGitReviewSnapshot) -> String {
        if snapshot.selectedPath != nil {
            return "No tracked diff for selected file. Preview may still show current contents."
        }
        return snapshot.hasChanges ? "No tracked diff in bounded view." : "No diff."
    }
}
