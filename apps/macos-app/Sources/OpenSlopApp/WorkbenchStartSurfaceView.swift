import SwiftUI
import WorkbenchCore

struct WorkbenchStartSurfaceView: View {
    let emptyState: WorkbenchTimelineEmptyState
    @Binding var promptText: String
    @Binding var claudeReceiptPromptText: String
    @Binding var selectedProvider: String
    @Binding var selectedModel: String
    @Binding var selectedEffort: String
    let executionProfileStatus: DaemonExecutionProfileStatus?
    let executionProfileError: String?
    let isExecutionProfileLoading: Bool
    let claudeRuntimeStatus: DaemonClaudeRuntimeStatus?
    let claudeRuntimeError: String?
    let isClaudeRuntimeLoading: Bool
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

                Text(surfaceTitle)
                    .font(.largeTitle.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(surfaceDetail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 620)
            }

            startProfileRow
            startProfileStatusLine

            if selectedProvider == "Claude" {
                claudeReceiptSurface
            } else {
                codexPromptSurface

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
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Button(startSessionButtonTitle, action: onStartSession)
                        .buttonStyle(.bordered)
                        .disabled(isStartDisabled)
                    Text(surfaceRecoveryHint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if selectedProvider == "Claude" {
                    Label(claudeStatusLine, systemImage: claudeStatusIcon)
                        .font(.caption)
                        .foregroundStyle(claudeRuntimeStatus?.available == true ? Color.secondary : Color.orange)
                }
            }
            .frame(maxWidth: 720, alignment: .leading)

            Spacer(minLength: 48)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var codexPromptSurface: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Спросите агента о проекте, коде или проверке…", text: $promptText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body)
                .lineLimit(3...6)
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 14)
                .onSubmit {
                    if !isSubmitDisabled {
                        onSubmit()
                    }
                }

            Divider()

            HStack(spacing: 12) {
                Label(workspaceTitle, systemImage: "folder")
                Label(branchTitle, systemImage: "point.3.connected.trianglepath.dotted")
                Spacer(minLength: 0)
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
    }

    private var claudeReceiptSurface: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Label("Claude receipt prompt", systemImage: "checkmark.seal")
                    .font(.headline)
                Spacer(minLength: 0)
                Text("\(claudeReceiptPromptBytes)/\(DaemonClaudeReceiptPromptPolicy.maxBytes) bytes")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(claudeReceiptPromptValidationMessage == nil ? Color.secondary : Color.orange)
            }

            Text("Один короткий proof-запрос уходит в core-daemon. OpenSlop сохраняет только read-only receipt в списке сессий.")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $claudeReceiptPromptText)
                    .font(.body.monospaced())
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 86, maxHeight: 130)
                    .padding(10)
                    .background(.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        if DaemonClaudeReceiptPromptPolicy.trimmed(claudeReceiptPromptText).isEmpty {
                            Text("Текст одного Claude receipt proof…")
                                .font(.body.monospaced())
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 18)
                                .allowsHitTesting(false)
                        }
                    }

                if let claudeReceiptPromptValidationMessage {
                    Label(claudeReceiptPromptValidationMessage, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Label("один bounded receipt · история, resume, approvals, tools и tracing закрыты", systemImage: "lock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                Label(workspaceTitle, systemImage: "folder")
                Label(branchTitle, systemImage: "point.3.connected.trianglepath.dotted")
                Spacer(minLength: 0)
                Label("диалоговый режим закрыт", systemImage: "lock")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: 720, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.separator.opacity(0.35), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.06), radius: 22, y: 10)
    }


    private var claudeReceiptPromptBytes: Int {
        DaemonClaudeReceiptPromptPolicy.byteCount(
            DaemonClaudeReceiptPromptPolicy.trimmed(claudeReceiptPromptText)
        )
    }

    private var claudeReceiptPromptValidationMessage: String? {
        DaemonClaudeReceiptPromptPolicy.validationMessage(for: claudeReceiptPromptText)
    }

    private var startSessionButtonTitle: String {
        selectedProvider == "Claude" ? "Создать Claude receipt session" : "Запустить живую Codex session"
    }

    private var surfaceTitle: String {
        selectedProvider == "Claude" ? "Создать Claude receipt" : emptyState.title
    }

    private var surfaceDetail: String {
        selectedProvider == "Claude"
            ? "Запусти один bounded Claude proof. OpenSlop сохранит только read-only receipt в session list."
            : emptyState.detail
    }

    private var surfaceRecoveryHint: String {
        selectedProvider == "Claude"
            ? "Это один receipt proof. Resume, approvals, tools, tracing и диалоговый режим пока закрыты."
            : emptyState.recoveryHint
    }

    private var claudeStatusLine: String {
        if isClaudeRuntimeLoading {
            return "Проверяем локальный Claude runtime…"
        }

        if let claudeRuntimeError, !claudeRuntimeError.isEmpty {
            return "Claude status failed: \(claudeRuntimeError)"
        }

        guard let claudeRuntimeStatus else {
            return "Claude runtime status ещё не загружен. Живой запуск остаётся закрыт."
        }

        if claudeRuntimeStatus.available {
            return "\(claudeRuntimeStatus.versionLabel) найден. S05d создаёт read-only receipt по bounded prompt; диалоговый режим закрыт."
        }

        return "Claude runtime недоступен. GUI держит этот provider fail-closed."
    }

    private var claudeStatusIcon: String {
        claudeRuntimeStatus?.available == true ? "checkmark.seal" : "exclamationmark.triangle"
    }

    private var startProfileRow: some View {
        HStack(spacing: 8) {
            startProfileMenu(title: selectedProvider, systemImage: "sparkles") {
                Picker("Agent", selection: $selectedProvider) {
                    Text("Codex").tag("Codex")
                    Text("Claude").tag("Claude")
                }
            }

            startProfileMenu(title: selectedModel, systemImage: "cpu") {
                Picker("Model", selection: $selectedModel) {
                    ForEach(models(for: selectedProvider), id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
            }

            startProfileMenu(title: selectedEffort, systemImage: "slider.horizontal.3") {
                Picker("Effort", selection: $selectedEffort) {
                    Text("Medium").tag("Medium")
                    Text("High").tag("High")
                    Text("Max").tag("Max")
                }
            }

            Spacer(minLength: 0)
        }
        .font(.callout.weight(.medium))
        .frame(maxWidth: 720, alignment: .leading)
    }

    private var startProfileStatusLine: some View {
        HStack(spacing: 8) {
            Image(systemName: startProfileStatusIcon)
                .foregroundStyle(startProfileStatusColor)
            Text(startProfileStatusText)
                .font(.caption)
                .foregroundStyle(startProfileStatusColor)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: 720, alignment: .leading)
    }

    private var startProfileStatusText: String {
        if isExecutionProfileLoading {
            return "Проверяем capability для выбранного агента…"
        }
        if let executionProfileError, !executionProfileError.isEmpty {
            return "Capability status недоступен: \(executionProfileError)"
        }
        guard let profile = executionProfileStatus?.profile(for: selectedProvider) else {
            return "Capability status пока unknown."
        }
        if let blockingReason = profile.blockingReason, !blockingReason.isEmpty {
            return blockingReason
        }
        let modes = profile.supportedModes.joined(separator: ", ")
        return "\(profile.provider): \(profile.statusLabel) · modes \(modes)"
    }

    private var startProfileStatusIcon: String {
        executionProfileStatus?.profile(for: selectedProvider)?.available == true ? "checkmark.seal" : "exclamationmark.triangle"
    }

    private var startProfileStatusColor: Color {
        executionProfileStatus?.profile(for: selectedProvider)?.available == true ? .secondary : .orange
    }

    private func startProfileMenu<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Menu {
            content()
        } label: {
            Label(title, systemImage: systemImage)
                .lineLimit(1)
        }
        .menuStyle(.borderlessButton)
        .onChange(of: selectedProvider) { _, provider in
            guard models(for: provider).contains(selectedModel) else {
                selectedModel = WorkbenchShellState.defaultModel
                return
            }
        }
    }

    private func models(for provider: String) -> [String] {
        if let profile = executionProfileStatus?.profile(for: provider), !profile.models.isEmpty {
            return profile.models
        }

        switch provider {
        case "Claude":
            return [WorkbenchShellState.defaultModel, "claude-haiku", "claude-sonnet", "claude-opus"]
        default:
            return [WorkbenchShellState.defaultModel, "gpt-5.4", "gpt-5.4-mini", "gpt-5.3-codex"]
        }
    }
}
