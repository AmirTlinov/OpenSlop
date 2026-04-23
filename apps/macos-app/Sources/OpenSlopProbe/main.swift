import Darwin
import Foundation
import WorkbenchCore

do {
    let projection = try CoreDaemonClient().fetchSessionProjection()
    print("projection=\(projection.kind) count=\(projection.sessions.count)")
    for session in projection.sessions {
        print("- \(session.id) | \(session.workspace) | \(session.branch) | \(session.provider) | \(session.status)")
    }
} catch {
    fputs("OpenSlopProbe failed: \(error.localizedDescription)\n", stderr)
    exit(EXIT_FAILURE)
}
