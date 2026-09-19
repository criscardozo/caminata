import Foundation

struct WalkStats: Equatable, Sendable {
    var distance: Double
    var elapsed: TimeInterval
    var movingTime: TimeInterval
    var elevationGain: Double

    static let zero = WalkStats(distance: 0, elapsed: 0, movingTime: 0, elevationGain: 0)

    /// Seconds per kilometre, or nil when too little ground has been covered for
    /// the figure to mean anything.
    var averagePace: TimeInterval? {
        guard distance >= 50, movingTime > 0 else { return nil }
        return movingTime / (distance / 1000)
    }

    /// Metres per second over the time actually spent moving.
    var averageSpeed: Double? {
        guard movingTime > 0 else { return nil }
        return distance / movingTime
    }
}

extension WalkStats {
    /// A gap longer than this means the fixes stopped arriving (suspended app,
    /// tunnel, lost signal) rather than the walker standing still, so it does
    /// not count towards moving time.
    static let maximumGap: TimeInterval = 30

    /// Below this speed the walker is treated as stopped.
    static let movingSpeedThreshold: Double = 0.5

    /// Altitude noise below this is ignored when accumulating climb.
    static let elevationThreshold: Double = 3

    static func compute(from points: [TrackPoint], endedAt: Date? = nil) -> WalkStats {
        guard let first = points.first else { return .zero }

        var distance: Double = 0
        var movingTime: TimeInterval = 0
        var elevationGain: Double = 0
        var elevationReference = first.altitude

        for (previous, current) in zip(points, points.dropFirst()) {
            let segment = GeoMath.distance(from: previous.coordinate, to: current.coordinate)
            distance += segment

            let interval = current.timestamp.timeIntervalSince(previous.timestamp)
            if interval > 0, interval <= maximumGap, segment / interval >= movingSpeedThreshold {
                movingTime += interval
            }

            let climb = current.altitude - elevationReference
            if climb > elevationThreshold {
                elevationGain += climb
                elevationReference = current.altitude
            } else if climb < -elevationThreshold {
                elevationReference = current.altitude
            }
        }

        let last = endedAt ?? points[points.count - 1].timestamp
        return WalkStats(
            distance: distance,
            elapsed: max(0, last.timeIntervalSince(first.timestamp)),
            movingTime: movingTime,
            elevationGain: elevationGain
        )
    }
}
