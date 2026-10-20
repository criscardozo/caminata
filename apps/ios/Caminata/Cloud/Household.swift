import Foundation

/// The two accounts Caminata is for. Firestore's rules are what actually keep
/// everyone else out; this copy exists so the app can say so at sign-in rather
/// than letting a stranger sign in and then fail every upload in silence.
/// Keep it in step with firebase/firestore.rules and apps/web/app.js.
enum Household {
    static let emails: Set<String> = [
        "cardozocristian@gmail.com",
        "pereznatalialourdes@gmail.com"
    ]

    static func allows(_ email: String?) -> Bool {
        guard let email else { return false }
        return emails.contains(email.lowercased())
    }
}
