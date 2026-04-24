import SwiftUI
import WorkbenchCore

struct ComposerBarView: View {
    @Binding var promptText: String
    @Binding var selectedProvider: String
    @Binding var selectedModel: String
    @Binding var selectedEffort: String
    let claudeRuntimeStatus: DaemonClaudeRuntimeStatus?
    let claudeRuntimeError: String?
    let isClaudeRuntimeLoading: Bool
    let onSubmit: () -> Void
    let isSubmitDisabled: Bool

    var body: some View {
        VStack(spacing: 9) {
            HStack(alignment: .bottom, spacing: 12) {
                TextField("Опишите задачу. Агент, модель и режим выбираются здесь…", text: $promptText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(2...5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(.separator.opacity(0.35), lineWidth: 1)
                    }

                Button(action: onSubmit) {
                    Image(systemName: "arrow.up")
                        .font(.headline)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(Circle())
                .disabled(isSubmitDisabled)
                .keyboardShortcut(.return, modifiers: .command)
            }

            HStack(spacing: 8) {
                profileMenu(
                    title: selectedProvider,
                    systemImage: "sparkles",
                    accessibilityLabel: "Agent"
                ) {
                    Picker("Agent", selection: $selectedProvider) {
                        Text("Codex").tag("Codex")
                        Text("Claude").tag("Claude")
                    }
                }

                profileMenu(
                    title: selectedModel,
                    systemImage: "cpu",
                    accessibilityLabel: "Model"
                ) {
                    Picker("Model", selection: $selectedModel) {
                        ForEach(models(for: selectedProvider), id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                }

                profileMenu(
                    title: selectedEffort,
                    systemImage: "slider.horizontal.3",
                    accessibilityLabel: "Effort"
                ) {
                    Picker("Effort", selection: $selectedEffort) {
                        Text("Medium").tag("Medium")
                        Text("High").tag("High")
                        Text("Max").tag("Max")
                    }
                }

                if selectedProvider == "Claude" {
                    Text(claudeComposerStatus)
                        .font(.caption)
                        .foregroundStyle(claudeRuntimeStatus?.available == true ? Color.secondary : Color.orange)
                        .lineLimit(1)
                }

                Spacer()
            }
            .font(.callout.weight(.medium))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.bar)
        .onChange(of: selectedProvider) { _, provider in
            guard models(for: provider).contains(selectedModel) else {
                selectedModel = WorkbenchShellState.defaultModel
                return
            }
        }
    }

    private func profileMenu<Content: View>(
        title: String,
        systemImage: String,
        accessibilityLabel: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Menu {
            content()
        } label: {
            Label(title, systemImage: systemImage)
                .lineLimit(1)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(.quaternary, in: Capsule())
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel(accessibilityLabel)
    }

    private func models(for provider: String) -> [String] {
        switch provider {
        case "Claude":
            return [WorkbenchShellState.defaultModel, "claude-haiku", "claude-sonnet", "claude-opus"]
        default:
            return [WorkbenchShellState.defaultModel, "gpt-5.4", "gpt-5.4-mini", "gpt-5.3-codex"]
        }
    }

    private var claudeComposerStatus: String {
        if isClaudeRuntimeLoading {
            return "проверяем Claude…"
        }
        if let claudeRuntimeError, !claudeRuntimeError.isEmpty {
            return "Claude недоступен"
        }
        guard let claudeRuntimeStatus else {
            return "Claude неизвестен"
        }
        if claudeRuntimeStatus.available {
            return "\(claudeRuntimeStatus.versionLabel) · receipt-only"
        }
        return "Claude недоступен"
    }
}
