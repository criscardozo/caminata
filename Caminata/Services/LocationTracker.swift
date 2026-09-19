import CoreLocation
import Foundation

/// The slice of CoreLocation the recorder depends on, so the recording rules
/// can be tested without a location manager in the loop.
@MainActor
protocol LocationTracking: AnyObject {
    var authorizationStatus: CLAuthorizationStatus { get }
    var onLocations: (([CLLocation]) -> Void)? { get set }
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)? { get set }
    var onFailure: ((Error) -> Void)? { get set }

    func requestAuthorization()
    func start()
    func stop()
}

/// Thin wrapper over CLLocationManager.
///
/// Callbacks are delivered on the main queue, because the manager is created
/// there; everything downstream of it is main-actor isolated to match.
@MainActor
final class LocationTracker: NSObject, LocationTracking {
    private let manager: CLLocationManager

    var onLocations: (([CLLocation]) -> Void)?
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?
    var onFailure: ((Error) -> Void)?

    var authorizationStatus: CLAuthorizationStatus { manager.authorizationStatus }

    init(manager: CLLocationManager = CLLocationManager()) {
        self.manager = manager
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.activityType = .fitness
        manager.distanceFilter = 5
        // Left to its own devices iOS pauses updates when it thinks you have
        // stopped, and never reliably resumes them mid-walk.
        manager.pausesLocationUpdatesAutomatically = false
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func start() {
        // When-in-use authorisation is enough to keep receiving updates in the
        // background, as long as the app declares the location background mode
        // and shows the status indicator.
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
    }
}

extension LocationTracker: @preconcurrency CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        onLocations?(locations)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        onAuthorizationChange?(manager.authorizationStatus)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // A transient "unknown location" is normal while the first fix settles.
        if let clError = error as? CLError, clError.code == .locationUnknown { return }
        onFailure?(error)
    }
}

extension TrackPoint {
    init(_ location: CLLocation) {
        self.init(
            coordinate: Coordinate(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            ),
            altitude: location.altitude,
            horizontalAccuracy: location.horizontalAccuracy,
            speed: location.speed,
            timestamp: location.timestamp
        )
    }
}
