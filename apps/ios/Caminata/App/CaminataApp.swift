import GoogleSignIn
import SwiftUI

@main
struct CaminataApp: App {
    init() {
        FirebaseBootstrap.configureIfPossible()
    }

    var body: some Scene {
        WindowGroup {
            TrackingView()
                .onOpenURL { GIDSignIn.sharedInstance.handle($0) }
                .task {
                    guard FirebaseBootstrap.isConfigured,
                          GIDSignIn.sharedInstance.hasPreviousSignIn() else { return }
                    _ = try? await GIDSignIn.sharedInstance.restorePreviousSignIn()
                }
        }
    }
}
