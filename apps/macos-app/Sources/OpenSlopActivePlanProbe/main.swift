import Darwin
import Foundation
import WorkbenchCore

@main
struct OpenSlopActivePlanProbe {
    static func main() async {
        do {
            let projection = try await CoreDaemonClient().fetchActivePlanProjection()
            print("active_plan_kind=\(projection.kind) total=\(projection.counts.total) done=\(projection.counts.done) active=\(projection.counts.active) planned=\(projection.counts.planned)")

            guard projection.kind == "active_plan_projection" else {
                fail("unexpected projection kind: \(projection.kind)")
            }
            guard projection.counts.total == projection.slices.count, projection.counts.total > 0 else {
                fail("slice counts are inconsistent or empty")
            }
            guard projection.slices.contains(where: { $0.id == "S01g-premium-timeline" && $0.status == "done" && $0.reviewStatus == "pass" }) else {
                fail("S01g closure was not visible as done/pass")
            }
            guard let active = projection.activeSlice else {
                fail("active slice missing")
            }
            print("active_plan_current=\(active.id) status=\(active.status) review=\(active.reviewStatus) proof=\(active.proofStatus) visual=\(active.visualStatus)")
        } catch {
            fail(error.localizedDescription)
        }
    }
}

private func fail(_ message: String) -> Never {
    fputs("FAIL: \(message)\n", stderr)
    exit(1)
}
