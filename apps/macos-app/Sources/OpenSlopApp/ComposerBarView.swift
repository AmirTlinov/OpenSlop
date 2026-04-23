import SwiftUI
import WorkbenchCore

struct ComposerBarView: View {
    @Binding var promptText: String
    @Binding var selectedProvider: String
    @Binding var selectedEffort: String
    let claudeRuntimeStatus: DaemonClaudeRuntimeStatus?
    let claudeRuntimeError: String?
    let isClaudeRuntimeLoading: Bool
    let onSubmit: () -> Void
    let isSubmitDisabled: Bool

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .bottom, spacing: 12) {
                TextField("Спросите агента о текущей session…", text: $promptText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(2...5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
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

            HStack(spacing: 14) {
                Picker("Provider", selection: $selectedProvider) {
                    Text("Codex").tag("Codex")
                    Text("Claude").tag("Claude")
                }
                .pickerStyle(.menu)
                .frame(width: 140)

                Picker("Effort", selection: $selectedEffort) {
                    Text("Medium").tag("Medium")
                    Text("High").tag("High")
                    Text("Max").tag("Max")
                }
                .pickerStyle(.menu)
                .frame(width: 120)

                if selectedProvider == "Claude" {
                    Text(claudeComposerStatus)
                        .font(.caption)
                        .foregroundStyle(claudeRuntimeStatus?.available == true ? Color.secondary : Color.orange)
                        .lineLimit(1)
                }

                Spacer()
            }
            .font(.callout)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.bar)
    }

    private var claudeComposerStatus: String {
        if isClaudeRuntimeLoading {
            return "Claude status loading…"
        }
        if let claudeRuntimeError, !claudeRuntimeError.isEmpty {
            return "Claude status failed"
        }
        guard let claudeRuntimeStatus else {
            return "Claude status unknown"
        }
        if claudeRuntimeStatus.available {
            return "\(claudeRuntimeStatus.versionLabel) · status only"
        }
        return "Claude unavailable"
    }
}
