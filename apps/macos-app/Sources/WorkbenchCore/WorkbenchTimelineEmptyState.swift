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
                title: "Нет выбранной session",
                systemImage: "rectangle.stack",
                detail: "Центр окна ждёт выбранную session из sidebar.",
                recoveryHint: "Создай живую Codex session или дождись session list от daemon."
            )
        }

        if transcriptItemCount == 0 {
            return WorkbenchTimelineEmptyState(
                title: "Transcript пуст",
                systemImage: "text.bubble",
                detail: "\(selectedSessionTitle): реальных timeline items пока нет.",
                recoveryHint: "Отправь первый turn, чтобы центр начал показывать события transcript."
            )
        }

        return WorkbenchTimelineEmptyState(
            title: "Transcript недоступен",
            systemImage: "exclamationmark.bubble",
            detail: "\(selectedSessionTitle): transcript snapshot сейчас не materialized в shell.",
            recoveryHint: "Если это seeded session, нажми «Запустить» для живой Codex session."
        )
    }
}
