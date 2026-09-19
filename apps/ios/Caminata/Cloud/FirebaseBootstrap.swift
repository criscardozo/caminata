import FirebaseCore
import Foundation

/// Firebase is optional: without `GoogleService-Info.plist` the app still
/// records, draws and emails a walk exactly as before, and only the history
/// on the web is missing. Everything cloud-side goes through this check,
/// because touching `Auth` or `Firestore` before `configure()` traps.
@MainActor
enum FirebaseBootstrap {
    static var isConfigured: Bool {
        Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
    }

    /// Tracked here rather than by asking `FirebaseApp.app()`, because that
    /// call is itself what logs "The default Firebase app has not yet been
    /// configured" -- the guard would report the very problem it prevents.
    private static var hasConfigured = false

    static func configureIfPossible() {
        guard isConfigured, !hasConfigured else { return }
        hasConfigured = true
        FirebaseApp.configure()
    }
}
