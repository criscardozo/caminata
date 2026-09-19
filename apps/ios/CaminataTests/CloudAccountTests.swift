import XCTest
@testable import Caminata

/// Covers the one piece of the account that is checkable without Firebase:
/// the URL scheme Google hands control back through, which lives in two
/// places nothing couples.
@MainActor
final class CloudAccountTests: XCTestCase {
    private let clientID = "123456789-abcdefg.apps.googleusercontent.com"
    private let reversed = "com.googleusercontent.apps.123456789-abcdefg"

    func testTheReversedClientIDIsTheComponentsBackwards() {
        XCTAssertEqual(FirebaseAccount.reversedClientID(from: clientID), reversed)
    }

    func testReversingIsItsOwnInverse() {
        let roundTrip = FirebaseAccount.reversedClientID(
            from: FirebaseAccount.reversedClientID(from: clientID)
        )
        XCTAssertEqual(roundTrip, clientID)
    }

    func testARegisteredSchemeIsAccepted() {
        let bundle = StubBundle(schemes: [reversed])
        XCTAssertNil(FirebaseAccount.missingURLScheme(clientID: clientID, bundle: bundle))
    }

    /// The case that costs an afternoon: a new Firebase app issues a new OAuth
    /// client, and replacing only GoogleService-Info.plist leaves the old
    /// scheme registered.
    func testAStaleSchemeIsReportedWithTheOneThatWasExpected() {
        let bundle = StubBundle(schemes: ["com.googleusercontent.apps.000000-stale"])
        XCTAssertEqual(
            FirebaseAccount.missingURLScheme(clientID: clientID, bundle: bundle),
            reversed
        )
    }

    func testAnUnconfiguredBuildIsReportedRatherThanPassingSilently() {
        XCTAssertEqual(
            FirebaseAccount.missingURLScheme(clientID: clientID, bundle: StubBundle(schemes: [])),
            reversed
        )
    }
}

/// A Bundle that answers CFBundleURLTypes with whatever the test wants.
private final class StubBundle: Bundle, @unchecked Sendable {
    private let schemes: [String]

    init(schemes: [String]) {
        self.schemes = schemes
        super.init()
    }

    override func object(forInfoDictionaryKey key: String) -> Any? {
        guard key == "CFBundleURLTypes" else { return nil }
        return [["CFBundleURLSchemes": schemes]]
    }
}
