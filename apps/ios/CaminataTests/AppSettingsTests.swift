import XCTest
@testable import Caminata

@MainActor
final class AppSettingsTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() async throws {
        suiteName = "AppSettingsTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    /// The caption is burned into the exported image, so it is opt-in.
    func testTheCaptionIsOffUntilSomebodyTurnsItOn() {
        XCTAssertFalse(AppSettings(defaults: defaults).captionOnImage)
    }

    func testTheChoiceSurvivesTheAppBeingRelaunched() {
        let settings = AppSettings(defaults: defaults)
        settings.captionOnImage = true

        // A second instance stands in for the next launch.
        XCTAssertTrue(AppSettings(defaults: defaults).captionOnImage)
    }

    func testTurningItBackOffAlsoSticks() {
        let settings = AppSettings(defaults: defaults)
        settings.captionOnImage = true
        settings.captionOnImage = false

        XCTAssertFalse(AppSettings(defaults: defaults).captionOnImage)
    }
}

final class WebHistoryTests: XCTestCase {
    func testAWalkLinksToItselfOnTheWeb() throws {
        let id = UUID()
        let url = WebHistory.url(for: id)

        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.host, "caminata.cardozo.dev")
        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(
            components.queryItems?.first(where: { $0.name == "walk" })?.value,
            id.uuidString
        )
    }
}
