import SwiftUI

@main
struct CaminataWatchApp: App {
    @State private var link = PhoneLink()

    var body: some Scene {
        WindowGroup {
            WalkView(link: link)
        }
    }
}
