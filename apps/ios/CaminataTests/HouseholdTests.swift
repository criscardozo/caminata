import XCTest
@testable import Caminata

final class HouseholdTests: XCTestCase {
    func testBothOfUsAreLetIn() {
        XCTAssertTrue(Household.allows("cardozocristian@gmail.com"))
        XCTAssertTrue(Household.allows("pereznatalialourdes@gmail.com"))
    }

    /// Google hands addresses back in whatever case they were typed.
    func testCaseDoesNotMatter() {
        XCTAssertTrue(Household.allows("CardozoCristian@Gmail.com"))
    }

    func testAnybodyElseIsNot() {
        XCTAssertFalse(Household.allows("someone@gmail.com"))
        XCTAssertFalse(Household.allows("cardozocristian@gmail.com.evil.com"))
        XCTAssertFalse(Household.allows(""))
        XCTAssertFalse(Household.allows(nil))
    }
}
