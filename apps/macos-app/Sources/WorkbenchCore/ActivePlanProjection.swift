import Foundation

public struct DaemonActivePlanProjection: Codable, Equatable, Sendable {
    public let kind: String
    public let generatedAtUnixMs: UInt64
    public let roadmapPath: String
    public let activeSliceId: String?
    public let selectionReason: String
    public let counts: DaemonActivePlanCounts
    public let slices: [DaemonActivePlanSlice]
    public let warnings: [String]

    public var activeSlice: DaemonActivePlanSlice? {
        guard let activeSliceId else {
            return nil
        }
        return slices.first { $0.id == activeSliceId }
    }

    public var isUnavailable: Bool {
        slices.isEmpty
    }
}

public struct DaemonActivePlanCounts: Codable, Equatable, Sendable {
    public let total: Int
    public let done: Int
    public let active: Int
    public let planned: Int
    public let blocked: Int
}

public struct DaemonActivePlanSlice: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let outcome: String
    public let dependsOn: String
    public let status: String
    public let roadmapStatus: String
    public let slicePath: String
    public let reviewStatus: String
    public let proofStatus: String
    public let visualStatus: String

    public var isDone: Bool {
        status == "done"
    }

    public var needsAttention: Bool {
        [status, reviewStatus, proofStatus, visualStatus].contains { value in
            value == "blocked" || value == "block" || value == "fail"
        }
    }
}
