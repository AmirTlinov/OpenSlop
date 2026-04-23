import Darwin
import Foundation
import WorkbenchCore

@main
struct OpenSlopTerminalTailProbe {
    static func main() {
        let bigOutput = (1...220)
            .map { String(format: "LINE-%03d", $0) }
            .joined(separator: "\n") + "\nDONE\n"

        let transcript = DaemonCodexTranscript(
            kind: "codex.thread",
            threadId: "thread-tail-probe",
            preview: "tail probe",
            threadStatus: "completed",
            turnCount: 1,
            lastTurnStatus: "completed",
            items: [
                DaemonCodexTranscriptItem(
                    id: "item-tail-probe",
                    turnId: "turn-tail-probe",
                    kind: "command",
                    title: "Synthetic terminal command",
                    text: bigOutput,
                    turnStatus: "completed",
                    command: "python3 synthetic.py",
                    processId: "proc-tail-probe",
                    exitCode: 0,
                    terminalStdin: "\n"
                ),
            ]
        )

        guard let surface = DaemonCodexTerminalSurfaceProjector.liveSurface(from: transcript) else {
            fail("terminal surface did not materialize from synthetic transcript.")
        }

        print("did_clip=\(surface.outputTail.didClip)")
        print("hidden_lines=\(surface.outputTail.hiddenLineCount)")
        print("total_lines=\(surface.outputTail.totalLineCount)")
        print("visible_chars=\(surface.outputTail.visibleText.count)")
        print("summary=\(surface.outputTail.summary ?? "none")")

        guard surface.outputTail.didClip else {
            fail("large terminal output was not clipped.")
        }

        guard surface.outputTail.hiddenLineCount > 0 else {
            fail("clipped surface did not report hidden lines.")
        }

        guard surface.outputTail.totalLineCount >= 221 else {
            fail("total line count looks wrong.")
        }

        guard !surface.outputTail.visibleText.contains("LINE-001") else {
            fail("oldest terminal lines leaked into the visible tail.")
        }

        guard surface.outputTail.visibleText.contains("LINE-220") else {
            fail("latest terminal lines were lost from the visible tail.")
        }

        guard surface.outputTail.visibleText.contains("DONE") else {
            fail("terminal tail lost the final DONE marker.")
        }

        let smallTail = DaemonBoundedOutputTailProjector.tail(
            "alpha\nbeta\n",
            policy: .inspectorOutput
        )

        print("small_clip=\(smallTail.didClip)")

        guard smallTail.didClip == false else {
            fail("small output should stay untouched.")
        }
    }

    private static func fail(_ message: String) -> Never {
        fputs("OpenSlopTerminalTailProbe failed: \(message)\n", stderr)
        exit(EXIT_FAILURE)
    }
}
