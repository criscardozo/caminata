import Foundation
import Observation

/// The handful of choices the app remembers between launches.
@MainActor
@Observable
final class AppSettings {
    private enum Key {
        static let captionOnImage = "settings.captionOnImage"
        static let routeColor = "settings.routeColor"
    }

    private let defaults: UserDefaults

    /// Off by default. The caption is burned into the image for good, and the
    /// places a walk usually gets sent -- a message, an email that already
    /// says the same figures -- carry that context anyway.
    var captionOnImage: Bool {
        didSet { defaults.set(captionOnImage, forKey: Key.captionOnImage) }
    }

    /// The colour the route is drawn in, on the live map, on the exported
    /// image and on the web. Stored as hex because that is what travels.
    var routeColorHex: String {
        didSet {
            guard RouteColor.isValid(routeColorHex) else {
                routeColorHex = oldValue
                return
            }
            defaults.set(routeColorHex, forKey: Key.routeColor)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.string(forKey: Key.routeColor)
        self.routeColorHex = stored.flatMap { RouteColor.isValid($0) ? $0 : nil }
            ?? RouteColor.default
        // `bool(forKey:)` is false for a key that was never written, which is
        // the default this wants.
        self.captionOnImage = defaults.bool(forKey: Key.captionOnImage)
    }
}
