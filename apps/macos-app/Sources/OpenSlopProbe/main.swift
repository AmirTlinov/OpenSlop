import Darwin
import Foundation
import WorkbenchCore

@main
struct OpenSlopProbe {
    static func main() async {
        let client = CoreDaemonClient()

        do {
            let first = try await client.fetchSessionProjection()
            let firstPID = try await client.daemonProcessIdentifier()
            let second = try await client.fetchSessionProjection()
            let secondPID = try await client.daemonProcessIdentifier()
            let reused = firstPID == secondPID
            let containsPersistedProof = second.sessions.contains(where: { $0.id == "s02-persisted-session-store" })

            print("transport=stdio pid1=\(firstPID) pid2=\(secondPID) reused=\(reused)")
            print("first_projection=\(first.kind) count=\(first.sessions.count)")
            print("second_projection=\(second.kind) count=\(second.sessions.count)")
            print("contains_persisted_proof=\(containsPersistedProof)")

            for session in second.sessions {
                print("- \(session.id) | \(session.workspace) | \(session.branch) | \(session.provider) | \(session.status)")
            }

            guard reused else {
                fputs("OpenSlopProbe failed: daemon transport was not reused.\n", stderr)
                exit(EXIT_FAILURE)
            }

            guard containsPersistedProof else {
                fputs("OpenSlopProbe failed: persisted proof session missing from rehydrated projection.\n", stderr)
                exit(EXIT_FAILURE)
            }
        } catch {
            fputs("OpenSlopProbe failed: \(error.localizedDescription)\n", stderr)
            exit(EXIT_FAILURE)
        }
    }
}
