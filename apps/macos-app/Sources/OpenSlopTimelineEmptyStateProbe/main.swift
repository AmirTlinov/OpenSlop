import Darwin
import Foundation
import WorkbenchCore

@main
struct OpenSlopTimelineEmptyStateProbe {
    static func main() {
        let noSession = WorkbenchTimelineEmptyStateProjector.project(
            selectedSessionTitle: nil,
            transcriptItemCount: nil
        )
        assertState(
            noSession,
            title: "Что нам сделать в OpenSlop?",
            image: "sparkles.rectangle.stack",
            mustContain: "Codex session"
        )

        let emptyTranscript = WorkbenchTimelineEmptyStateProjector.project(
            selectedSessionTitle: "Live Codex",
            transcriptItemCount: 0
        )
        assertState(
            emptyTranscript,
            title: "Что делаем дальше?",
            image: "text.bubble",
            mustContain: "Live Codex"
        )

        let unavailableTranscript = WorkbenchTimelineEmptyStateProjector.project(
            selectedSessionTitle: "Seeded Session",
            transcriptItemCount: nil
        )
        assertState(
            unavailableTranscript,
            title: "Эта session ещё не раскрыта",
            image: "exclamationmark.bubble",
            mustContain: "Seeded Session"
        )

        let liveTranscript = WorkbenchTimelineEmptyStateProjector.project(
            selectedSessionTitle: "Live Codex",
            transcriptItemCount: 2
        )

        guard liveTranscript == nil else {
            fail("live transcript with items should not produce an empty state.")
        }

        let forbiddenFragments = [
            "daemon unavailable",
            "session_list",
            "notLoaded",
            "materialized",
            "proof target",
            "S04",
        ]

        for state in [noSession, emptyTranscript, unavailableTranscript].compactMap({ $0 }) {
            let combined = [state.title, state.detail, state.recoveryHint].joined(separator: "\n")
            for fragment in forbiddenFragments {
                guard !combined.localizedCaseInsensitiveContains(fragment) else {
                    fail("empty state leaked engineering/proof wording \(fragment): \(combined)")
                }
            }
        }

        print("no_session_title=\(noSession?.title ?? "nil")")
        print("empty_transcript_title=\(emptyTranscript?.title ?? "nil")")
        print("unavailable_transcript_title=\(unavailableTranscript?.title ?? "nil")")
        print("live_transcript_empty_state=\(liveTranscript == nil ? "nil" : "unexpected")")
    }

    private static func assertState(
        _ state: WorkbenchTimelineEmptyState?,
        title: String,
        image: String,
        mustContain: String
    ) {
        guard let state else {
            fail("expected empty state \(title), got nil.")
        }

        guard state.title == title else {
            fail("expected title \(title), got \(state.title).")
        }

        guard state.systemImage == image else {
            fail("expected image \(image), got \(state.systemImage).")
        }

        let combined = [state.detail, state.recoveryHint].joined(separator: "\n")
        guard combined.contains(mustContain) else {
            fail("state \(title) did not include expected truth fragment \(mustContain).")
        }
    }

    private static func fail(_ message: String) -> Never {
        fputs("OpenSlopTimelineEmptyStateProbe failed: \(message)\n", stderr)
        exit(EXIT_FAILURE)
    }
}
