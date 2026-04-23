import Foundation

public struct WorkbenchTimelineEmptyState: Equatable, Sendable {
    public var title: String
    public var systemImage: String
    public var detail: String
    public var recoveryHint: String

    public init(
        title: String,
        systemImage: String,
        detail: String,
        recoveryHint: String
    ) {
        self.title = title
        self.systemImage = systemImage
        self.detail = detail
        self.recoveryHint = recoveryHint
    }
}

public enum WorkbenchTimelineEmptyStateProjector {
    public static func project(
        selectedSessionTitle: String?,
        transcriptItemCount: Int?
    ) -> WorkbenchTimelineEmptyState? {
        if let transcriptItemCount, transcriptItemCount > 0 {
            return nil
        }

        guard let selectedSessionTitle, !selectedSessionTitle.isEmpty else {
            return WorkbenchTimelineEmptyState(
                title: "Что нам сделать в OpenSlop?",
                systemImage: "sparkles.rectangle.stack",
                detail: "Выбери чат слева или начни новую живую Codex session.",
                recoveryHint: "Центр окна готов принять первый запрос. Runtime-правда останется за core daemon."
            )
        }

        if transcriptItemCount == 0 {
            return WorkbenchTimelineEmptyState(
                title: "Что делаем дальше?",
                systemImage: "text.bubble",
                detail: "\(selectedSessionTitle) готова, но сообщений в timeline пока нет.",
                recoveryHint: "Отправь первый turn, чтобы здесь появилась реальная история работы."
            )
        }

        return WorkbenchTimelineEmptyState(
            title: "Эта session ещё не раскрыта",
            systemImage: "exclamationmark.bubble",
            detail: "\(selectedSessionTitle) есть в списке, но live transcript сейчас недоступен.",
            recoveryHint: "Для seeded session нажми «Запустить». Для live session попробуй обновить."
        )
    }
}
