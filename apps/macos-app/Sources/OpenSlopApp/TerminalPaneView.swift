import SwiftUI
import WorkbenchCore

struct TerminalPaneView: View {
    let surface: DaemonCodexTerminalSurface

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Live terminal")
                        .font(.headline)
                    Text("Read-only live PTY surface из текущего streamed transcript.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("live-only")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.quaternary, in: Capsule())
            }

            TerminalMetaRow(label: "Command", value: surface.command)
            TerminalMetaRow(label: "Process", value: surface.processId)
            TerminalMetaRow(label: "Turn", value: surface.turnStatus)

            if let exitCode = surface.exitCode {
                TerminalMetaRow(label: "Exit", value: "\(exitCode)")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("stdin raw")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(escaped(surface.terminalStdin))
                    .font(.footnote.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.background, in: RoundedRectangle(cornerRadius: 10))
            }

            MonospacedTailBlockView(
                label: "Output",
                tail: surface.outputTail,
                emptyPlaceholder: "output waiting...",
                minHeight: 140,
                idealHeight: 180
            )

            Text("Ordinary readback пока не удерживает этот live signal. Pane честно materialize'ится только на streamed transcript.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }

    private func escaped(_ value: String) -> String {
        var rendered = "\""
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\n":
                rendered += "\\n"
            case "\r":
                rendered += "\\r"
            case "\t":
                rendered += "\\t"
            case "\"":
                rendered += "\\\""
            case "\\":
                rendered += "\\\\"
            default:
                if scalar.value < 0x20 || scalar.value == 0x7F {
                    rendered += String(format: "\\u{%X}", scalar.value)
                } else {
                    rendered.append(String(scalar))
                }
            }
        }
        rendered += "\""
        return rendered
    }
}

private struct TerminalMetaRow: View {
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
