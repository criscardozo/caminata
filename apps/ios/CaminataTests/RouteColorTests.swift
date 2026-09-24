import SwiftUI
import XCTest
@testable import Caminata

final class RouteColorTests: XCTestCase {
    func testAHexStringSurvivesARoundTrip() {
        for hex in RouteColor.presets {
            let back = RouteColor.hex(from: RouteColor.color(from: hex))
            XCTAssertEqual(back.uppercased(), hex.uppercased(), "\(hex) did not survive")
        }
    }

    func testTheDefaultIsUsedWhenTheStringIsNotAColour() {
        let fallback = RouteColor.uiColor(from: RouteColor.default)
        for bad in ["", "#", "nope", "#12345", "#1234567", "#GGGGGG"] {
            XCTAssertEqual(RouteColor.uiColor(from: bad), fallback, "\(bad) should fall back")
        }
    }

    func testValidationAcceptsWhatTheAppWritesAndRejectsTheRest() {
        XCTAssertTrue(RouteColor.isValid("#D9293D"))
        XCTAssertTrue(RouteColor.isValid("d9293d"))
        XCTAssertFalse(RouteColor.isValid("#D9293"))
        XCTAssertFalse(RouteColor.isValid("red"))
        XCTAssertFalse(RouteColor.isValid(""))
    }

    func testAHashIsOptionalOnTheWayIn() {
        XCTAssertEqual(RouteColor.uiColor(from: "#0E9F6E"), RouteColor.uiColor(from: "0E9F6E"))
    }
}

@MainActor
final class WalkNamingTests: XCTestCase {
    private func metadata(name: String?) -> WalkMetadata {
        var m = WalkMetadata(id: UUID(), startedAt: TestRoute.start, endedAt: TestRoute.start)
        m.name = name
        return m
    }

    func testAWalkWithANameShowsIt() {
        XCTAssertEqual(WalkFormatting.displayName(for: metadata(name: "Palermo → Recoleta")), "Palermo → Recoleta")
    }

    func testAWalkWithoutANameFallsBackToItsDate() {
        let shown = WalkFormatting.displayName(for: metadata(name: nil))
        XCTAssertEqual(shown, WalkFormatting.walkName(startedAt: TestRoute.start))
    }

    /// A name of only spaces is what an empty text field on the web sends.
    func testABlankNameIsTreatedAsNoName() {
        let shown = WalkFormatting.displayName(for: metadata(name: "   "))
        XCTAssertEqual(shown, WalkFormatting.walkName(startedAt: TestRoute.start))
    }
}
