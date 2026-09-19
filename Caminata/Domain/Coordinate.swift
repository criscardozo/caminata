import Foundation

/// A geographic position, independent of CoreLocation so that route maths stay
/// testable without a device or a simulator.
struct Coordinate: Equatable, Codable, Sendable {
    var latitude: Double
    var longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

enum GeoMath {
    /// Mean Earth radius (IUGG), in metres.
    static let earthRadius: Double = 6_371_008.8

    /// Great-circle distance in metres.
    static func distance(from start: Coordinate, to end: Coordinate) -> Double {
        let lat1 = start.latitude * .pi / 180
        let lat2 = end.latitude * .pi / 180
        let deltaLat = (end.latitude - start.latitude) * .pi / 180
        let deltaLon = (end.longitude - start.longitude) * .pi / 180

        let a = sin(deltaLat / 2) * sin(deltaLat / 2)
            + cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(max(0, 1 - a)))
        return earthRadius * c
    }

    /// Projects a coordinate onto a local plane in metres, centred on `origin`.
    /// Accurate enough over the span of a walk, and lets us do planar geometry.
    static func localPlanarPoint(_ coordinate: Coordinate, origin: Coordinate) -> (x: Double, y: Double) {
        let metresPerDegreeLatitude = earthRadius * .pi / 180
        let metresPerDegreeLongitude = metresPerDegreeLatitude * cos(origin.latitude * .pi / 180)
        return (
            x: (coordinate.longitude - origin.longitude) * metresPerDegreeLongitude,
            y: (coordinate.latitude - origin.latitude) * metresPerDegreeLatitude
        )
    }
}
