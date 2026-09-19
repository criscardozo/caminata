import XCTest
@testable import Caminata

final class GPXExporterTests: XCTestCase {
    func testProducesParseableXML() {
        let gpx = GPXExporter.gpx(for: TestRoute.walk(), name: "Morning walk")
        let parser = XMLParser(data: Data(gpx.utf8))
        XCTAssertTrue(parser.parse(), "GPX did not parse: \(String(describing: parser.parserError))")
    }

    func testWritesOneTrackPointPerRecordedFix() {
        let walk = TestRoute.walk()
        let gpx = GPXExporter.gpx(for: walk, name: "Walk")
        let occurrences = gpx.components(separatedBy: "<trkpt ").count - 1
        XCTAssertEqual(occurrences, walk.points.count)
    }

    func testCoordinatesKeepEnoughPrecisionToBeUseful() {
        let walk = TestRoute.walk()
        let gpx = GPXExporter.gpx(for: walk, name: "Walk")
        XCTAssertTrue(gpx.contains("lat=\"-34.6037220\""), "Unexpected coordinate formatting")
    }

    func testTimestampsAreInternetDateTime() {
        let gpx = GPXExporter.gpx(for: TestRoute.walk(), name: "Walk")
        XCTAssertTrue(gpx.contains("<time>2023-11-14T22:13:20Z</time>"))
    }

    func testNamesAreEscapedSoTheFileStaysValid() {
        let gpx = GPXExporter.gpx(for: TestRoute.walk(), name: "Tom & Jerry's <walk>")
        XCTAssertTrue(gpx.contains("Tom &amp; Jerry&apos;s &lt;walk&gt;"))
        XCTAssertTrue(XMLParser(data: Data(gpx.utf8)).parse())
    }

    func testAnEmptyWalkStillProducesValidGPX() {
        let walk = Walk(
            metadata: WalkMetadata(id: UUID(), startedAt: TestRoute.start, endedAt: TestRoute.start),
            points: []
        )
        let gpx = GPXExporter.gpx(for: walk, name: "Empty")
        XCTAssertTrue(XMLParser(data: Data(gpx.utf8)).parse())
    }

    func testTheExportedTrackIsAvailableAsACIArtifact() {
        let gpx = GPXExporter.gpx(for: TestRoute.walk(), name: "Sample walk")
        CIOutput.write(Data(gpx.utf8), named: "sample-walk.gpx")
    }
}
