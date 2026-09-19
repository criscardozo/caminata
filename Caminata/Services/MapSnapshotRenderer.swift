import MapKit
import UIKit

/// Renders a walk as a single map image with the route drawn on top.
struct MapSnapshotRenderer {
    enum RenderError: Error {
        case noCoordinates
    }

    var size = CGSize(width: 1000, height: 1000)
    /// Points closer than this to the line they sit on add nothing once the
    /// route is a few pixels wide.
    var simplifyTolerance: Double = 2

    func render(walk: Walk, caption: String?) async throws -> UIImage {
        let coordinates = RouteSimplifier.simplify(walk.coordinates, tolerance: simplifyTolerance)
        guard let region = MapRegionFitter.region(for: coordinates) else {
            throw RenderError.noCoordinates
        }

        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = size
        options.mapType = .standard
        options.pointOfInterestFilter = .excludingAll
        options.showsBuildings = false
        // An emailed image should look the same whoever took it, so it does not
        // follow the sender's dark mode setting.
        options.traitCollection = UITraitCollection(userInterfaceStyle: .light)

        let snapshot = try await MKMapSnapshotter(options: options).start()
        let route = coordinates.map { coordinate in
            snapshot.point(for: CLLocationCoordinate2D(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            ))
        }

        return RouteOverlayDrawer.image(base: snapshot.image, route: route, caption: caption)
    }
}
