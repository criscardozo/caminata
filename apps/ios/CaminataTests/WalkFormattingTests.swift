import XCTest
@testable import Caminata

final class WalkFormattingTests: XCTestCase {
    func testShortDistancesReadInMetres() {
        XCTAssertEqual(WalkFormatting.distance(840), "840 m")
    }

    func testLongDistancesReadInKilometres() {
        XCTAssertEqual(WalkFormatting.distance(3204), "3.20 km")
    }

    func testDurationsUnderAnHourOmitTheHourField() {
        XCTAssertEqual(WalkFormatting.duration(754), "12:34")
    }

    func testLongDurationsIncludeHours() {
        XCTAssertEqual(WalkFormatting.duration(3725), "1:02:05")
    }

    func testAnUnknownPaceIsShownAsAPlaceholder() {
        XCTAssertEqual(WalkFormatting.pace(nil), "--")
    }

    func testPaceReadsAsMinutesPerKilometre() {
        XCTAssertEqual(WalkFormatting.pace(725), "12:05 /km")
    }

    func testFileStampsAreSortableAndFilesystemSafe() {
        // The stamp is local time, so assert its shape rather than a fixed date.
        let stamp = WalkFormatting.fileStamp(Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertNotNil(
            stamp.range(of: "^\\d{4}-\\d{2}-\\d{2}-\\d{4}$", options: .regularExpression),
            "Unexpected stamp: \(stamp)"
        )
    }

    func testTheCaptionCarriesTheHeadlineNumbers() {
        let walk = TestRoute.walk()
        let caption = WalkFormatting.summaryCaption(for: walk)
        XCTAssertTrue(caption.contains(WalkFormatting.distance(walk.stats.distance)))
        XCTAssertTrue(caption.contains("·"))
    }
}
