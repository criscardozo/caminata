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

    /// What to call this walk. Filled in from the places it went through when
    /// it is stopped, and editable on the web. Nil for a walk recorded before
    /// naming existed, or one the geocoder could not place.
    var name: String?

    /// The colour this walk was drawn in, so the web matches the image that
    /// was exported at the time rather than whatever the setting says now.
    var routeColor: String?

    /// When this walk reached Firestore. Nil for a walk recorded before the
    /// cloud existed, one stopped with no signal, or one recorded while
    /// signed out -- all of which are retried later.
    var uploadedAt: Date?

    /// Every pause, in order. Optional so a walk written before pausing
    /// existed still decodes; read it through `pauseList`.
    var pauses: [WalkPause]?

    var pauseList: [WalkPause] { pauses ?? [] }

    var isActive: Bool { endedAt == nil }

    var isPaused: Bool { isActive && pauseList.last.map { $0.end == nil } == true }

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

    /// The walk cut at its pauses. Whatever happened between pausing and
    /// resuming -- a coffee, a bus -- is not part of the route, so it is not
    /// drawn as a line or counted as distance.
    var segments: [[TrackPoint]] {
        Walk.segments(of: points, pauses: metadata.pauseList)
    }

    static func segments(of points: [TrackPoint], pauses: [WalkPause]) -> [[TrackPoint]] {
        var result: [[TrackPoint]] = []
        for point in points {
            if let previous = result.last?.last, !pauses.separates(previous.timestamp, point.timestamp) {
                result[result.count - 1].append(point)
            } else {
                result.append([point])
            }
        }
        return result
    }

    var stats: WalkStats {
        WalkStats.compute(from: points, endedAt: metadata.endedAt, pauses: metadata.pauseList)
    }
}
