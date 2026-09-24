import CoreLocation
import Foundation

/// Turns a route into the name of the place it went through.
///
/// Apple's reverse geocoder needs no API key and bills nothing, which is why
/// this happens on the phone rather than on the web: doing it in the browser
/// would mean Nominatim with its usage limits, or Google Geocoding with a
/// billing account attached.
@MainActor
protocol PlaceNaming: AnyObject {
    func name(startingAt start: Coordinate, endingAt end: Coordinate) async -> String?
}

@MainActor
final class PlaceNamer: PlaceNaming {
    private let geocoder = CLGeocoder()

    /// A walk that starts and ends somewhere different is named for both, in
    /// the order it was walked. Failing to name a walk is not an error worth
    /// surfacing: it just keeps the date it always had.
    func name(startingAt start: Coordinate, endingAt end: Coordinate) async -> String? {
        guard let from = await suburb(at: start) else { return nil }
        guard let to = await suburb(at: end), to != from else { return from }
        return "\(from) → \(to)"
    }

    private func suburb(at coordinate: Coordinate) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let placemark = try? await geocoder.reverseGeocodeLocation(location).first else {
            return nil
        }
        // subLocality is the neighbourhood where one is defined; locality is
        // the town, which is the useful answer everywhere else.
        return placemark.subLocality ?? placemark.locality ?? placemark.administrativeArea
    }
}
