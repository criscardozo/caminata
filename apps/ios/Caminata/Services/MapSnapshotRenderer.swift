import MapKit
import UIKit

/// Renders a walk as a single map image with the route drawn on top.
struct MapSnapshotRenderer {
    enum RenderError: Error {
        case noCoordinates
    }

    var size = CGSize(width: 1000, height: 1000)
    var style = RouteOverlayStyle()
    /// Points closer than this to the line they sit on add nothing once the
    /// route is a few pixels wide.
    var simplifyTolerance: Double = 2

    func render(walk: Walk, caption: String?) async throws -> UIImage {
        // Simplified a stretch at a time, so a pause is never smoothed over
        // into a line the walker did not take.
        let stretches = walk.segments.map {
            RouteSimplifier.simplify($0.map(\.coordinate), tolerance: simplifyTolerance)
        }
        guard let region = MapRegionFitter.region(for: stretches.flatMap { $0 }) else {
            throw RenderError.noCoordinates
        }

        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = size
        let configuration = MKStandardMapConfiguration(elevationStyle: .flat)
        configuration.pointOfInterestFilter = .excludingAll
        configuration.showsTraffic = false
        options.preferredConfiguration = configuration
        // An emailed image should look the same whoever took it, so it does not
        // follow the sender's dark mode setting.
        options.traitCollection = UITraitCollection(userInterfaceStyle: .light)

        let snapshot = try await MKMapSnapshotter(options: options).start()
        let routes = stretches.map { stretch in
            stretch.map { coordinate in
                snapshot.point(for: CLLocationCoordinate2D(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                ))
            }
        }

        return RouteOverlayDrawer.image(
            base: snapshot.image,
            routes: routes,
            caption: caption,
            style: style
        )
    }
}
