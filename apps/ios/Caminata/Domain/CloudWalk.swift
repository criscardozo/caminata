import Foundation

/// A finished walk in the shape the web history reads.
///
/// Only summary figures and a simplified route travel: the raw fixes stay on
/// the phone, where the GPX export already covers them. A walk this size is a
/// few kilobytes, which keeps the whole history inside the free Firestore
/// quota no matter how long the walk was.
struct CloudWalk: Equatable, Sendable {
    /// Metres. Tighter than the tolerance used for the emailed image, because
    /// the web map can be zoomed in and the image cannot.
    static let routeTolerance: Double = 5

    var id: UUID
    var name: String?
    var routeColor: String?
    var startedAt: Date
    var endedAt: Date
    var distance: Double
    var movingTime: TimeInterval
    var elevationGain: Double
    var pointCount: Int
    /// Latitude, longitude, latitude, longitude. Firestore cannot nest an
    /// array inside an array, and a list of maps spends several times the
    /// bytes on repeating the keys "lat" and "lng".
    var route: [Double]
    /// Where each stretch after the first begins, counted in points (pairs in
    /// `route`). Empty for a walk that was never paused. Kept beside the flat
    /// route rather than nesting arrays, which Firestore does not allow.
    var breaks: [Int]

    init?(walk: Walk) {
        guard let endedAt = walk.endedAt ?? walk.points.last?.timestamp else { return nil }

        let stats = walk.stats
        let stretches = walk.segments.map {
            RouteSimplifier.simplify($0.map(\.coordinate), tolerance: Self.routeTolerance)
        }
        var breaks: [Int] = []
        var count = 0
        for stretch in stretches {
            if count > 0 { breaks.append(count) }
            count += stretch.count
        }

        self.id = walk.id
        self.name = walk.metadata.name
        self.routeColor = walk.metadata.routeColor
        self.startedAt = walk.startedAt
        self.endedAt = endedAt
        self.distance = stats.distance
        self.movingTime = stats.movingTime
        self.elevationGain = stats.elevationGain
        self.pointCount = walk.points.count
        self.route = stretches.flatMap { $0.flatMap { [$0.latitude, $0.longitude] } }
        self.breaks = breaks
    }

    var segments: [[Coordinate]] {
        let all = coordinates
        let edges = [0] + breaks + [all.count]
        return zip(edges, edges.dropFirst()).map { Array(all[$0..<$1]) }
    }

    var coordinates: [Coordinate] {
        stride(from: 0, to: route.count - 1, by: 2).map {
            Coordinate(latitude: route[$0], longitude: route[$0 + 1])
        }
    }
}
