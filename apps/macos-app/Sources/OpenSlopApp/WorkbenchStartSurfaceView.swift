import SwiftUI
import WorkbenchCore

struct WorkbenchStartSurfaceView: View {
    let emptyState: WorkbenchTimelineEmptyState
    @Binding var promptText: String
    let selectedProvider: String
    let selectedEffort: String
    let workspaceTitle: String
    let branchTitle: String
    let onStartSession: () -> Void
    let onSubmit: () -> Void
    let isStartDisabled: Bool
    let isSubmitDisabled: Bool

    private let suggestions = [
        "Проверь последние изменения и назови риски.",
        "Сделай маленький end-to-end slice с проверкой.",
        "Объясни, что сейчас не доказано в проекте.",
    ]

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 48)

            VStack(spacing: 12) {
                Image(systemName: emptyState.systemImage)
                    .font(.system(size: 34, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)

                Text(emptyState.title)
                    .font(.largeTitle.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(emptyState.detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 620)
            }

            VStack(alignment: .leading, spacing: 0) {
                TextField("Спросите агента о проекте, коде или проверке…", text: $promptText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .lineLimit(3...6)
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 14)
                    .onSubmit(onSubmit)

                Divider()

                HStack(spacing: 12) {
                    Label(workspaceTitle, systemImage: "folder")
                    Label(branchTitle, systemImage: "point.3.connected.trianglepath.dotted")
                    Spacer(minLength: 0)
                    Menu {
                        Text("Provider truth приходит из текущего shell state.")
                    } label: {
                        Label(selectedProvider, systemImage: selectedProvider == "Claude" ? "moon.stars" : "sparkles")
                    }
                    .menuStyle(.borderlessButton)

                    Menu {
                        Text("Effort пока shell-level preference.")
                    } label: {
                        Label(selectedEffort, systemImage: "slider.horizontal.3")
                    }
                    .menuStyle(.borderlessButton)

                    Button(action: onSubmit) {
                        Image(systemName: "arrow.up")
                            .font(.headline)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.borderedProminent)
                    .clipShape(Circle())
                    .disabled(isSubmitDisabled)
                    .keyboardShortcut(.return, modifiers: .command)
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
            .frame(maxWidth: 720)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.separator.opacity(0.35), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.06), radius: 22, y: 10)

            VStack(spacing: 0) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        promptText = suggestion
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.turn.down.right")
                                .foregroundStyle(.secondary)
                            Text(suggestion)
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)

                    if suggestion != suggestions.last {
                        Divider()
                    }
                }
            }
            .frame(maxWidth: 720)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Button("Запустить живую Codex session", action: onStartSession)
                        .buttonStyle(.bordered)
                        .disabled(isStartDisabled)
                    Text(emptyState.recoveryHint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if selectedProvider == "Claude" {
                    Label("Claude runtime planned in S05. Сейчас живой запуск доступен только для Codex.", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: 720, alignment: .leading)

            Spacer(minLength: 48)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
