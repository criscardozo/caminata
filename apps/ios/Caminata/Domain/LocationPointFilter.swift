import Foundation

enum PointRejection: Equatable, Sendable {
    /// CoreLocation reports a negative accuracy when the fix is invalid.
    case invalidFix
    case poorAccuracy(Double)
    case stale(TimeInterval)
    case outOfOrder
    case tooClose(Double)
    case implausibleSpeed(Double)
}

enum FilterDecision: Equatable, Sendable {
    case accept
    case reject(PointRejection)

    var isAccepted: Bool { self == .accept }
}

/// Decides which GPS fixes are worth keeping. Keeping this separate from
/// CoreLocation means every rule can be tested against synthetic points.
struct LocationPointFilter: Sendable {
    var maximumHorizontalAccuracy: Double = 50
    var maximumAge: TimeInterval = 5
    var minimumDistance: Double = 3
    /// Fast enough to be a GPS jump rather than a person; a train still passes.
    var maximumSpeed: Double = 50

    func evaluate(_ candidate: TrackPoint, previous: TrackPoint?, now: Date) -> FilterDecision {
        guard candidate.horizontalAccuracy >= 0 else {
            return .reject(.invalidFix)
        }
        guard candidate.horizontalAccuracy <= maximumHorizontalAccuracy else {
            return .reject(.poorAccuracy(candidate.horizontalAccuracy))
        }

        // Age is only checked for the first fix of a walk. CoreLocation hands
        // over a cached position the moment updates start, and seeding a walk
        // with it puts the start marker wherever the phone last had a fix.
        // Later fixes arrive in batches when iOS wakes the app, so they are
        // legitimately older than `now`; dropping those would punch holes in
        // exactly the background stretch the app exists to record. They are
        // sanity-checked against their predecessor instead.
        guard let previous else {
            let age = now.timeIntervalSince(candidate.timestamp)
            return age <= maximumAge ? .accept : .reject(.stale(age))
        }

        // A batch can arrive out of order, and a replayed cached fix would
        // otherwise be stitched into the route as if the walker had doubled
        // back in negative time.
        let interval = candidate.timestamp.timeIntervalSince(previous.timestamp)
        guard interval > 0 else { return .reject(.outOfOrder) }

        let distance = GeoMath.distance(from: previous.coordinate, to: candidate.coordinate)
        guard distance / interval <= maximumSpeed else {
            return .reject(.implausibleSpeed(distance / interval))
        }
        guard distance >= minimumDistance else {
            return .reject(.tooClose(distance))
        }

        return .accept
    }
}
