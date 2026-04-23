import SwiftUI
import WorkbenchCore

struct CommandExecControlPaneView: View {
    @Binding var proofMode: CommandExecProofMode
    @Binding var stdinText: String
    let surface: DaemonCodexCommandExecControlSurface?
    let onRun: () -> Void
    let onSendResize: () -> Void
    let onSendWrite: () -> Void
    let onSendWriteAndClose: () -> Void
    let onCloseStdin: () -> Void
    let onTerminate: () -> Void
    let isRunDisabled: Bool
    let isResizeDisabled: Bool
    let isWriteDisabled: Bool
    let isWriteAndCloseDisabled: Bool
    let isCloseStdinDisabled: Bool
    let isTerminateDisabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(proofMode.headline)
                        .font(.headline)
                    Text(proofMode.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(proofMode.detail)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Text(stageLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.quaternary, in: Capsule())
            }

            Picker("Proof mode", selection: $proofMode) {
                ForEach(CommandExecProofMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 6) {
                Text("argv proof command")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ScrollView {
                    Text(proofMode.command.joined(separator: "\n"))
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(minHeight: 84, idealHeight: 96)
                .background(.background, in: RoundedRectangle(cornerRadius: 10))
            }

            if let surface {
                HStack(spacing: 16) {
                    CommandExecMeta(label: "Process", value: surface.processId)

                    if let exitCode = surface.exitCode {
                        CommandExecMeta(label: "Exit", value: "\(exitCode)")
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(proofMode == .ptyResize ? "final stdin raw" : "stdin raw")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextEditor(text: $stdinText)
                    .font(.footnote.monospaced())
                    .frame(minHeight: 52, idealHeight: 60)
                    .padding(8)
                    .background(.background, in: RoundedRectangle(cornerRadius: 10))
            }

            if let surface, !surface.controlTrail.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("control trail")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ScrollView {
                        Text(surface.controlTrail)
                            .font(.footnote.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                    }
                    .frame(minHeight: 84, idealHeight: 96)
                    .background(.background, in: RoundedRectangle(cornerRadius: 10))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Output")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ScrollView {
                    Text(outputText)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(minHeight: 140, idealHeight: 180)
                .background(.background, in: RoundedRectangle(cornerRadius: 10))
            }

            if let errorText, !errorText.isEmpty {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Запустить proof lane", action: onRun)
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunDisabled)

                if proofMode == .ptyResize {
                    Button("Применить resize 100x40", action: onSendResize)
                        .disabled(isResizeDisabled)

                    Button("Отправить stdin + close", action: onSendWriteAndClose)
                        .disabled(isWriteAndCloseDisabled)
                } else {
                    Button("Отправить stdin", action: onSendWrite)
                        .disabled(isWriteDisabled)

                    Button("Закрыть stdin", action: onCloseStdin)
                        .disabled(isCloseStdinDisabled)

                    Button("Завершить", action: onTerminate)
                        .disabled(isTerminateDisabled)
                }

                Spacer()
            }

            Text(proofMode.footerNote)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }

    private var outputText: String {
        guard let surface else {
            return "Запусти standalone exec, чтобы увидеть live output."
        }

        let output = surface.mergedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        return output.isEmpty ? "output waiting..." : surface.mergedOutput
    }

    private var errorText: String? {
        surface?.lastError
    }

    private var stageLabel: String {
        switch surface?.stage {
        case .awaitingControl:
            return "awaiting control"
        case .completed:
            return "completed"
        case .failed:
            return "failed"
        case .running:
            return "running"
        default:
            return "idle"
        }
    }
}

private struct CommandExecMeta: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.footnote.monospaced())
                .textSelection(.enabled)
        }
    }
}
