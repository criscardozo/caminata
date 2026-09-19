import Foundation

/// One accepted GPS fix along a walk.
struct TrackPoint: Equatable, Codable, Sendable {
    var coordinate: Coordinate
    var altitude: Double
    var horizontalAccuracy: Double
    var speed: Double
    var timestamp: Date

    init(
        coordinate: Coordinate,
        altitude: Double = 0,
        horizontalAccuracy: Double = 5,
        speed: Double = -1,
        timestamp: Date
    ) {
        self.coordinate = coordinate
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
        self.speed = speed
        self.timestamp = timestamp
    }
}
