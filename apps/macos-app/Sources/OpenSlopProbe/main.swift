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

            print("transport=stdio pid1=\(firstPID) pid2=\(secondPID) reused=\(firstPID == secondPID)")
            print("first_projection=\(first.kind) count=\(first.sessions.count)")
            print("second_projection=\(second.kind) count=\(second.sessions.count)")

            for session in second.sessions {
                print("- \(session.id) | \(session.workspace) | \(session.branch) | \(session.provider) | \(session.status)")
            }
        } catch {
            fputs("OpenSlopProbe failed: \(error.localizedDescription)\n", stderr)
            exit(EXIT_FAILURE)
        }
    }
}
