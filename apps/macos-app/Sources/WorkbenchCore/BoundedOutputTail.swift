import Foundation

public struct DaemonBoundedOutputTail: Equatable, Sendable {
    public let visibleText: String
    public let didClip: Bool
    public let hiddenLineCount: Int
    public let hiddenCharacterCount: Int
    public let totalLineCount: Int
    public let totalCharacterCount: Int

    public init(
        visibleText: String,
        didClip: Bool,
        hiddenLineCount: Int,
        hiddenCharacterCount: Int,
        totalLineCount: Int,
        totalCharacterCount: Int
    ) {
        self.visibleText = visibleText
        self.didClip = didClip
        self.hiddenLineCount = hiddenLineCount
        self.hiddenCharacterCount = hiddenCharacterCount
        self.totalLineCount = totalLineCount
        self.totalCharacterCount = totalCharacterCount
    }

    public var summary: String? {
        guard didClip else {
            return nil
        }

        if hiddenLineCount > 0 {
            return "Показан хвост вывода. Скрыто сверху \(hiddenLineCount) строк."
        }

        return "Показан хвост вывода. Скрыто сверху \(hiddenCharacterCount) символов."
    }
}

public struct DaemonBoundedOutputTailPolicy: Equatable, Sendable {
    public let maxLines: Int
    public let maxCharacters: Int

    public init(maxLines: Int, maxCharacters: Int) {
        self.maxLines = maxLines
        self.maxCharacters = maxCharacters
    }

    public static let inspectorOutput = Self(maxLines: 160, maxCharacters: 12_000)
    public static let controlTrail = Self(maxLines: 80, maxCharacters: 4_000)
    public static let timelineTerminalPreview = Self(maxLines: 8, maxCharacters: 800)
}

public enum DaemonBoundedOutputTailProjector {
    public static func tail(
        _ text: String,
        policy: DaemonBoundedOutputTailPolicy
    ) -> DaemonBoundedOutputTail {
        guard !text.isEmpty else {
            return DaemonBoundedOutputTail(
                visibleText: "",
                didClip: false,
                hiddenLineCount: 0,
                hiddenCharacterCount: 0,
                totalLineCount: 0,
                totalCharacterCount: 0
            )
        }

        let totalLineCount = lineCount(in: text)
        let totalCharacterCount = text.count
        var visibleStart = startIndexForTailLines(in: text, maxLines: policy.maxLines)
        var visibleText = String(text[visibleStart...])

        if visibleText.count > policy.maxCharacters {
            let clippedCharacters = visibleText.count - policy.maxCharacters
            visibleStart = text.index(visibleStart, offsetBy: clippedCharacters)
            visibleText = String(text[visibleStart...])

            if let newline = visibleText.firstIndex(of: "\n"), newline < visibleText.index(before: visibleText.endIndex) {
                visibleText = String(visibleText[visibleText.index(after: newline)...])
            }
        }

        let hiddenCharacterCount = max(0, totalCharacterCount - visibleText.count)
        let visibleLineCount = lineCount(in: visibleText)
        let hiddenLineCount = max(0, totalLineCount - visibleLineCount)

        return DaemonBoundedOutputTail(
            visibleText: visibleText,
            didClip: hiddenLineCount > 0 || hiddenCharacterCount > 0,
            hiddenLineCount: hiddenLineCount,
            hiddenCharacterCount: hiddenCharacterCount,
            totalLineCount: totalLineCount,
            totalCharacterCount: totalCharacterCount
        )
    }

    private static func startIndexForTailLines(in text: String, maxLines: Int) -> String.Index {
        guard maxLines > 0 else {
            return text.endIndex
        }

        var remainingLines = maxLines
        var index = text.endIndex

        while index > text.startIndex {
            let previous = text.index(before: index)
            if text[previous] == "\n" {
                remainingLines -= 1
                if remainingLines == 0 {
                    return index
                }
            }
            index = previous
        }

        return text.startIndex
    }

    private static func lineCount(in text: String) -> Int {
        guard !text.isEmpty else {
            return 0
        }

        let count = text.unicodeScalars.reduce(into: 1) { count, scalar in
            if scalar == "\n" {
                count += 1
            }
        }

        if text.last == "\n" {
            return max(0, count - 1)
        }

        return count
    }
}
