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

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "This build has no Firebase configuration, so there is nothing to sign in to."
            case .noPresenter:
                return "Could not find a window to present the Google sign-in sheet."
            case .missingIdentityToken:
                return "Google signed you in but returned no identity token."
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
