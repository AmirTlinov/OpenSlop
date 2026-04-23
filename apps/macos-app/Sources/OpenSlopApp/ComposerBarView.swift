import SwiftUI

struct ComposerBarView: View {
    @Binding var promptText: String
    @Binding var selectedProvider: String
    @Binding var selectedEffort: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Опиши следующий bounded шаг", text: $promptText, axis: .vertical)
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

                Button("Новый turn") { }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .background(.bar)
    }
}
