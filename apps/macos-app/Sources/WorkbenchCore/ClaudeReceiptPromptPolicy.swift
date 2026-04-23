import Foundation

public enum DaemonClaudeReceiptPromptPolicy {
    public static let maxBytes = 512
    public static let defaultPrompt = "Reply with exactly OPENSLOP_CLAUDE_OK and nothing else."

    public static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func byteCount(_ value: String) -> Int {
        value.utf8.count
    }

    public static func validationMessage(for value: String) -> String? {
        let trimmedValue = trimmed(value)
        if trimmedValue.isEmpty {
            return "Нужен один bounded Claude receipt prompt."
        }

        let bytes = byteCount(trimmedValue)
        if bytes > maxBytes {
            return "Claude receipt prompt слишком большой: \(bytes)/\(maxBytes) bytes."
        }

        return nil
    }
}
