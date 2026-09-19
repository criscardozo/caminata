import Foundation

enum PointRejection: Equatable, Sendable {
    /// CoreLocation reports a negative accuracy when the fix is invalid.
    case invalidFix
    case poorAccuracy(Double)
    case stale(TimeInterval)
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

        let age = now.timeIntervalSince(candidate.timestamp)
        guard age <= maximumAge else {
            return .reject(.stale(age))
        }

        guard let previous else { return .accept }

        let distance = GeoMath.distance(from: previous.coordinate, to: candidate.coordinate)
        let interval = candidate.timestamp.timeIntervalSince(previous.timestamp)
        if interval > 0, distance / interval > maximumSpeed {
            return .reject(.implausibleSpeed(distance / interval))
        }
        guard distance >= minimumDistance else {
            return .reject(.tooClose(distance))
        }

        return .accept
    }
}
