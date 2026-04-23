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
            title: "Нет выбранной session",
            image: "rectangle.stack",
            mustContain: "sidebar"
        )

        let emptyTranscript = WorkbenchTimelineEmptyStateProjector.project(
            selectedSessionTitle: "Live Codex",
            transcriptItemCount: 0
        )
        assertState(
            emptyTranscript,
            title: "Transcript пуст",
            image: "text.bubble",
            mustContain: "Live Codex"
        )

        let unavailableTranscript = WorkbenchTimelineEmptyStateProjector.project(
            selectedSessionTitle: "Seeded Session",
            transcriptItemCount: nil
        )
        assertState(
            unavailableTranscript,
            title: "Transcript недоступен",
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

        let syntheticSummaryLeak = [
            noSession,
            emptyTranscript,
            unavailableTranscript,
        ].compactMap { $0 }.contains { state in
            [state.title, state.detail, state.recoveryHint]
                .joined(separator: "\n")
                .contains("daemon unavailable")
        }

        guard !syntheticSummaryLeak else {
            fail("empty state leaked caller-authored summary strings into center truth.")
        }

        for state in [noSession, emptyTranscript, unavailableTranscript].compactMap({ $0 }) {
            let combined = [state.title, state.detail, state.recoveryHint].joined(separator: "\n")
            guard !combined.contains("S04"), !combined.localizedCaseInsensitiveContains("proof target") else {
                fail("empty state leaked synthetic proof storytelling: \(combined)")
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
