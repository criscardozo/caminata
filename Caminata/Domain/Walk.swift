import Foundation

/// Everything about a walk except its points, so a list of walks can be shown
/// without reading every recorded fix off disk.
struct WalkMetadata: Equatable, Codable, Identifiable, Sendable {
    let id: UUID
    var startedAt: Date
    var endedAt: Date?

    /// Written once the walk is stopped, so the history list can show figures
    /// without reading every recorded point back off disk. Optional because a
    /// walk that is still in progress has none yet.
    var distance: Double?
    var movingTime: TimeInterval?
    var elevationGain: Double?

    var isActive: Bool { endedAt == nil }

    var duration: TimeInterval? {
        guard let endedAt else { return nil }
        return endedAt.timeIntervalSince(startedAt)
    }

    mutating func apply(_ stats: WalkStats) {
        distance = stats.distance
        movingTime = stats.movingTime
        elevationGain = stats.elevationGain
    }
}

struct Walk: Equatable, Identifiable, Sendable {
    var metadata: WalkMetadata
    var points: [TrackPoint]

    var id: UUID { metadata.id }
    var startedAt: Date { metadata.startedAt }
    var endedAt: Date? { metadata.endedAt }

    var coordinates: [Coordinate] { points.map(\.coordinate) }

    var stats: WalkStats {
        WalkStats.compute(from: points, endedAt: metadata.endedAt)
    }
}
