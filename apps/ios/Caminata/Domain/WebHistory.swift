import Foundation

/// The web history that shows the walks once they have been uploaded.
enum WebHistory {
    static let baseURL = URL(string: "https://caminata.cardozo.dev")!

    /// A link straight to one walk. It only resolves for whoever is signed in
    /// with the account that recorded it, which is why the app never offers
    /// the link for a walk that has not reached the cloud.
    static func url(for walkID: UUID) -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "walk", value: walkID.uuidString)]
        return components?.url ?? baseURL
    }
}
