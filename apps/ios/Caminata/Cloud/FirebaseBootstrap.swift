import FirebaseCore
import Foundation

/// Firebase is optional: without `GoogleService-Info.plist` the app still
/// records, draws and emails a walk exactly as before, and only the history
/// on the web is missing. Everything cloud-side goes through this check,
/// because touching `Auth` or `Firestore` before `configure()` traps.
enum FirebaseBootstrap {
    static var isConfigured: Bool {
        Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
    }

    static func configureIfPossible() {
        guard isConfigured, FirebaseApp.app() == nil else { return }
        FirebaseApp.configure()
    }
}
