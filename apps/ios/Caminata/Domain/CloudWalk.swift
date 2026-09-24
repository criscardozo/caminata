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

    init?(walk: Walk) {
        guard let endedAt = walk.endedAt ?? walk.points.last?.timestamp else { return nil }

        let stats = walk.stats
        let simplified = RouteSimplifier.simplify(walk.coordinates, tolerance: Self.routeTolerance)

        self.id = walk.id
        self.name = walk.metadata.name
        self.routeColor = walk.metadata.routeColor
        self.startedAt = walk.startedAt
        self.endedAt = endedAt
        self.distance = stats.distance
        self.movingTime = stats.movingTime
        self.elevationGain = stats.elevationGain
        self.pointCount = walk.points.count
        self.route = simplified.flatMap { [$0.latitude, $0.longitude] }
    }

    var coordinates: [Coordinate] {
        stride(from: 0, to: route.count - 1, by: 2).map {
            Coordinate(latitude: route[$0], longitude: route[$0 + 1])
        }
    }
}
