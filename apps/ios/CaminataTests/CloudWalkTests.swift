import XCTest
@testable import Caminata

final class CloudWalkTests: XCTestCase {
    func testAFinishedWalkCarriesItsSummaryFigures() throws {
        let walk = TestRoute.walk()
        let cloud = try XCTUnwrap(CloudWalk(walk: walk))

        XCTAssertEqual(cloud.id, walk.id)
        XCTAssertEqual(cloud.startedAt, walk.startedAt)
        XCTAssertEqual(cloud.distance, 600, accuracy: 5)
        XCTAssertEqual(cloud.pointCount, walk.points.count)
    }

    func testTheRouteTravelsAsInterleavedLatitudesAndLongitudes() throws {
        let walk = TestRoute.walk()
        let cloud = try XCTUnwrap(CloudWalk(walk: walk))

        XCTAssertEqual(cloud.route.count % 2, 0)
        XCTAssertEqual(cloud.coordinates.count, cloud.route.count / 2)
        XCTAssertEqual(cloud.coordinates[0].latitude, walk.coordinates[0].latitude, accuracy: 0.000001)
        XCTAssertEqual(cloud.coordinates[0].longitude, walk.coordinates[0].longitude, accuracy: 0.000001)
    }

    func testAStraightLegIsSimplifiedAwayButTheCornerSurvives() throws {
        let walk = TestRoute.walk()
        let cloud = try XCTUnwrap(CloudWalk(walk: walk))

        // Two straight legs meeting at a right angle reduce to their corners.
        XCTAssertLessThan(cloud.coordinates.count, walk.points.count)
        XCTAssertEqual(cloud.coordinates.first, walk.coordinates.first)
        XCTAssertEqual(cloud.coordinates.last, walk.coordinates.last)
    }

    func testAWalkWithNoEndAndNoPointsCannotBeUploaded() {
        let walk = Walk(
            metadata: WalkMetadata(id: UUID(), startedAt: TestRoute.start, endedAt: nil),
            points: []
        )
        XCTAssertNil(CloudWalk(walk: walk))
    }

    func testAnUnfinishedWalkFallsBackToItsLastFix() throws {
        let points = TestRoute.lShaped()
        let walk = Walk(
            metadata: WalkMetadata(id: UUID(), startedAt: TestRoute.start, endedAt: nil),
            points: points
        )
        let cloud = try XCTUnwrap(CloudWalk(walk: walk))
        XCTAssertEqual(cloud.endedAt, points[points.count - 1].timestamp)
    }
}
