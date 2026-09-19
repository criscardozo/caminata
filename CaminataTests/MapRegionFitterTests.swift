import MapKit
import XCTest
@testable import Caminata

final class MapRegionFitterTests: XCTestCase {
    func testAnEmptyRouteHasNoRegion() {
        XCTAssertNil(MapRegionFitter.region(for: []))
    }

    func testASinglePointGetsTheMinimumSpanRatherThanNoZoom() throws {
        let region = try XCTUnwrap(MapRegionFitter.region(for: [TestRoute.origin]))

        XCTAssertEqual(region.center.latitude, TestRoute.origin.latitude, accuracy: 0.000001)
        XCTAssertEqual(region.span.latitudeDelta, MapRegionFitter.minimumSpan, accuracy: 0.000001)
        XCTAssertEqual(region.span.longitudeDelta, MapRegionFitter.minimumSpan, accuracy: 0.000001)
    }

    func testTheRegionIsCentredOnTheBoundingBox() throws {
        let coordinates = [
            Coordinate(latitude: -34.60, longitude: -58.40),
            Coordinate(latitude: -34.62, longitude: -58.38)
        ]
        let region = try XCTUnwrap(MapRegionFitter.region(for: coordinates))

        XCTAssertEqual(region.center.latitude, -34.61, accuracy: 0.000001)
        XCTAssertEqual(region.center.longitude, -58.39, accuracy: 0.000001)
    }

    func testTheRegionLeavesRoomAroundTheRoute() throws {
        let coordinates = [
            Coordinate(latitude: -34.60, longitude: -58.40),
            Coordinate(latitude: -34.62, longitude: -58.38)
        ]
        let region = try XCTUnwrap(MapRegionFitter.region(for: coordinates))

        XCTAssertGreaterThan(region.span.latitudeDelta, 0.02)
        XCTAssertEqual(region.span.latitudeDelta, 0.02 * MapRegionFitter.padding, accuracy: 0.000001)
    }

    func testAWholeRouteFitsInsideTheRegion() throws {
        let coordinates = TestRoute.lShaped().map(\.coordinate)
        let region = try XCTUnwrap(MapRegionFitter.region(for: coordinates))

        for coordinate in coordinates {
            XCTAssertLessThanOrEqual(
                abs(coordinate.latitude - region.center.latitude),
                region.span.latitudeDelta / 2
            )
            XCTAssertLessThanOrEqual(
                abs(coordinate.longitude - region.center.longitude),
                region.span.longitudeDelta / 2
            )
        }
    }
}
