import Darwin
import Foundation
import WorkbenchCore

@main
struct OpenSlopCodexProbe {
    static func main() async {
        let client = CoreDaemonClient()

        do {
            let before = try await client.fetchSessionProjection()
            let beforePID = try await client.daemonProcessIdentifier()
            let bootstrap = try await client.startCodexSession()
            let after = try await client.fetchSessionProjection()
            let afterPID = try await client.daemonProcessIdentifier()

            let daemonReused = beforePID == afterPID
            let materialized = after.sessions.contains(where: { $0.id == bootstrap.session.id })
            let sameCanonicalID = bootstrap.session.id == bootstrap.providerThreadId
            let countDelta = after.sessions.count - before.sessions.count

            print("transport=\(bootstrap.transport) pid_before=\(beforePID) pid_after=\(afterPID) reused=\(daemonReused)")
            print("cli_version=\(bootstrap.cliVersion) model=\(bootstrap.model) approval_policy=\(bootstrap.approvalPolicy) sandbox=\(bootstrap.sandboxMode)")
            print("thread_id=\(bootstrap.providerThreadId) session_id=\(bootstrap.session.id) same_canonical_id=\(sameCanonicalID)")
            print("before_count=\(before.sessions.count) after_count=\(after.sessions.count) count_delta=\(countDelta)")
            print("materialized_in_projection=\(materialized) session_title=\(bootstrap.session.title)")
            print("instruction_sources=\(bootstrap.instructionSources.count) suppressed_notifications=\(bootstrap.initialize.suppressedNotificationMethods.count)")

            guard daemonReused else {
                fputs("OpenSlopCodexProbe failed: core-daemon process was not reused across bootstrap round-trip.\n", stderr)
                exit(EXIT_FAILURE)
            }

            guard sameCanonicalID else {
                fputs("OpenSlopCodexProbe failed: session id drifted away from provider thread id.\n", stderr)
                exit(EXIT_FAILURE)
            }

            guard materialized else {
                fputs("OpenSlopCodexProbe failed: started Codex session was not materialized in session_list projection.\n", stderr)
                exit(EXIT_FAILURE)
            }
        } catch {
            fputs("OpenSlopCodexProbe failed: \(error.localizedDescription)\n", stderr)
            exit(EXIT_FAILURE)
        }
    }
}
