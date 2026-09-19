import FirebaseAuth
import FirebaseCore
import Foundation
import GoogleSignIn
import UIKit

/// Who is signed in, if anyone. The web history reads what this account
/// writes, so signing in is the only thing that connects the two.
@MainActor
protocol CloudAccounting: AnyObject {
    /// False when the app was built without a Firebase configuration, in which
    /// case the UI hides the whole account section rather than offering a
    /// button that cannot work.
    var isAvailable: Bool { get }
    var userID: String? { get }
    var displayName: String? { get }
    var onChange: (() -> Void)? { get set }

    func signIn() async throws
    func signOut() throws
}

@MainActor
final class FirebaseAccount: CloudAccounting {
    enum AccountError: LocalizedError {
        case notConfigured
        case noPresenter
        case missingIdentityToken
        case urlSchemeMismatch(expected: String)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "This build has no Firebase configuration, so there is nothing to sign in to."
            case .noPresenter:
                return "Could not find a window to present the Google sign-in sheet."
            case .missingIdentityToken:
                return "Google signed you in but returned no identity token."
            case let .urlSchemeMismatch(expected):
                return """
                    This build cannot complete a Google sign-in: GoogleService-Info.plist \
                    expects the URL scheme \(expected), which is not registered. Set \
                    GOOGLE_REVERSED_CLIENT_ID in apps/ios/project.yml to that value and \
                    re-run xcodegen generate.
                    """
            }
        }
    }

    var onChange: (() -> Void)?

    /// Only ever touched from init and deinit, both of which run on the
    /// thread that created the account.
    nonisolated(unsafe) private var listener: AuthStateDidChangeListenerHandle?

    var isAvailable: Bool { FirebaseBootstrap.isConfigured }
    var userID: String? { isAvailable ? Auth.auth().currentUser?.uid : nil }

    var displayName: String? {
        guard let user = isAvailable ? Auth.auth().currentUser : nil else { return nil }
        return user.displayName ?? user.email
    }

    init() {
        guard isAvailable else { return }
        listener = Auth.auth().addStateDidChangeListener { [weak self] _, _ in
            MainActor.assumeIsolated { self?.onChange?() }
        }
    }

    deinit {
        if let listener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }

    func signIn() async throws {
        guard isAvailable, let clientID = FirebaseApp.app()?.options.clientID else {
            throw AccountError.notConfigured
        }
        guard let presenter = Self.topViewController() else {
            throw AccountError.noPresenter
        }
        if let expected = Self.missingURLScheme(clientID: clientID) {
            throw AccountError.urlSchemeMismatch(expected: expected)
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AccountError.missingIdentityToken
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        try await Auth.auth().signIn(with: credential)
        onChange?()
    }

    func signOut() throws {
        guard isAvailable else { return }
        GIDSignIn.sharedInstance.signOut()
        try Auth.auth().signOut()
        onChange?()
    }

    /// Google hands control back through a URL scheme, and that value lives in
    /// two places nothing couples: `GOOGLE_REVERSED_CLIENT_ID` in project.yml,
    /// which lands in `CFBundleURLTypes`, and `GoogleService-Info.plist`.
    /// Registering a new app in Firebase issues a new OAuth client, so
    /// replacing only the plist leaves sign-in rejected with no hint as to
    /// why. Checked up front so the failure says exactly what to fix.
    ///
    /// Returns the scheme that should have been registered, or nil when it is.
    static func missingURLScheme(clientID: String, bundle: Bundle = .main) -> String? {
        let expected = reversedClientID(from: clientID)
        let registered = (bundle.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? [])
            .flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
        return registered.contains(expected) ? nil : expected
    }

    /// `1234-abc.apps.googleusercontent.com` becomes
    /// `com.googleusercontent.apps.1234-abc`.
    static func reversedClientID(from clientID: String) -> String {
        clientID.split(separator: ".").reversed().joined(separator: ".")
    }

    /// Google Sign-In presents a sheet and so needs a view controller. SwiftUI
    /// has none to hand, so it is fished out of the active window scene.
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }

        var controller = scene?.keyWindow?.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }
}
