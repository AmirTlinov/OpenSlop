import SwiftUI

struct ComposerBarView: View {
    @Binding var promptText: String
    @Binding var selectedProvider: String
    @Binding var selectedEffort: String
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
                    Text("Claude runtime planned in S05")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .font(.callout)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(.bar)
    }
}
