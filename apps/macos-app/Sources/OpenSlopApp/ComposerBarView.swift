import SwiftUI

struct ComposerBarView: View {
    @Binding var promptText: String
    @Binding var selectedProvider: String
    @Binding var selectedEffort: String
    let onSubmit: () -> Void
    let isSubmitDisabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Напиши сообщение для живого turn", text: $promptText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...5)

            HStack {
                Picker("Provider", selection: $selectedProvider) {
                    Text("Codex").tag("Codex")
                    Text("Claude").tag("Claude")
                }
                .frame(width: 140)

                Picker("Effort", selection: $selectedEffort) {
                    Text("Medium").tag("Medium")
                    Text("High").tag("High")
                    Text("Max").tag("Max")
                }
                .frame(width: 140)

                Spacer()

                Button("Отправить", action: onSubmit)
                    .buttonStyle(.borderedProminent)
                    .disabled(isSubmitDisabled)
            }
        }
        .padding(16)
        .background(.bar)
    }
}
