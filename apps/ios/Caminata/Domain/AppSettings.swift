import Foundation
import Observation

/// The handful of choices the app remembers between launches.
@MainActor
@Observable
final class AppSettings {
    private enum Key {
        static let captionOnImage = "settings.captionOnImage"
    }

    private let defaults: UserDefaults

    /// Off by default. The caption is burned into the image for good, and the
    /// places a walk usually gets sent -- a message, an email that already
    /// says the same figures -- carry that context anyway.
    var captionOnImage: Bool {
        didSet { defaults.set(captionOnImage, forKey: Key.captionOnImage) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // `bool(forKey:)` is false for a key that was never written, which is
        // the default this wants.
        self.captionOnImage = defaults.bool(forKey: Key.captionOnImage)
    }
}
