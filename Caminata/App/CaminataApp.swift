import SwiftUI

@main
struct CaminataApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

struct RootView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.walk")
                .font(.system(size: 48))
            Text("Caminata")
                .font(.largeTitle.bold())
        }
    }
}
