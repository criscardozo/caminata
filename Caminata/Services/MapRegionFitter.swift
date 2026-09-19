import MapKit

enum MapRegionFitter {
    /// Roughly 220 m, so a walk that barely moved still gets a sensible zoom
    /// instead of filling the frame with one doorstep.
    static let minimumSpan: CLLocationDegrees = 0.002
    /// Breathing room around the route.
    static let padding: Double = 1.3

    static func region(for coordinates: [Coordinate]) -> MKCoordinateRegion? {
        guard let first = coordinates.first else { return nil }

        var minLatitude = first.latitude
        var maxLatitude = first.latitude
        var minLongitude = first.longitude
        var maxLongitude = first.longitude

        for coordinate in coordinates.dropFirst() {
            minLatitude = min(minLatitude, coordinate.latitude)
            maxLatitude = max(maxLatitude, coordinate.latitude)
            minLongitude = min(minLongitude, coordinate.longitude)
            maxLongitude = max(maxLongitude, coordinate.longitude)
        }

        let centre = CLLocationCoordinate2D(
            latitude: (minLatitude + maxLatitude) / 2,
            longitude: (minLongitude + maxLongitude) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLatitude - minLatitude) * padding, minimumSpan),
            longitudeDelta: max((maxLongitude - minLongitude) * padding, minimumSpan)
        )
        return MKCoordinateRegion(center: centre, span: span)
    }
}
