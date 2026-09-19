import XCTest
@testable import Caminata

final class WalkStatsTests: XCTestCase {
    func testEmptyWalkHasZeroStats() {
        XCTAssertEqual(WalkStats.compute(from: []), .zero)
    }

    func testDistanceAccumulatesAlongTheRoute() {
        let stats = WalkStats.compute(from: TestRoute.lShaped())
        // Two 300 m legs.
        XCTAssertEqual(stats.distance, 600, accuracy: 5)
    }

    func testElapsedSpansTheWholeWalk() {
        let points = TestRoute.lShaped()
        let stats = WalkStats.compute(from: points)
        let expected = points[points.count - 1].timestamp.timeIntervalSince(points[0].timestamp)
        XCTAssertEqual(stats.elapsed, expected, accuracy: 0.001)
    }

    func testStandingStillDoesNotCountAsMovingTime() {
        let start = TestRoute.start
        let points = [
            TrackPoint(coordinate: TestRoute.origin, timestamp: start),
            // 0.3 m in 10 s: below the moving threshold.
            TrackPoint(
                coordinate: TestRoute.offset(TestRoute.origin, northMetres: 0.3, eastMetres: 0),
                timestamp: start.addingTimeInterval(10)
            ),
            TrackPoint(
                coordinate: TestRoute.offset(TestRoute.origin, northMetres: 20, eastMetres: 0),
                timestamp: start.addingTimeInterval(30)
            )
        ]

        let stats = WalkStats.compute(from: points)
        XCTAssertEqual(stats.movingTime, 20, accuracy: 0.001)
        XCTAssertEqual(stats.elapsed, 30, accuracy: 0.001)
    }

    func testLongGapsDoNotCountAsMovingTime() {
        let start = TestRoute.start
        let points = [
            TrackPoint(coordinate: TestRoute.origin, timestamp: start),
            // Lost signal: 100 m covered but an hour of wall clock.
            TrackPoint(
                coordinate: TestRoute.offset(TestRoute.origin, northMetres: 100, eastMetres: 0),
                timestamp: start.addingTimeInterval(3600)
            )
        ]

        let stats = WalkStats.compute(from: points)
        XCTAssertEqual(stats.movingTime, 0)
        XCTAssertEqual(stats.distance, 100, accuracy: 1)
    }

    func testElevationGainIgnoresNoiseAndSumsRealClimbs() {
        let start = TestRoute.start
        let altitudes: [Double] = [100, 101, 99, 100, 120, 118, 140]
        let points = altitudes.enumerated().map { index, altitude in
            TrackPoint(
                coordinate: TestRoute.offset(
                    TestRoute.origin,
                    northMetres: Double(index) * 10,
                    eastMetres: 0
                ),
                altitude: altitude,
                timestamp: start.addingTimeInterval(Double(index) * 8)
            )
        }

        // 100 -> 120 -> 140, with the +/- 1 m wobble filtered out.
        XCTAssertEqual(WalkStats.compute(from: points).elevationGain, 40, accuracy: 0.001)
    }

    func testPaceIsUnavailableUntilEnoughGroundIsCovered() {
        let stats = WalkStats(distance: 20, elapsed: 60, movingTime: 60, elevationGain: 0)
        XCTAssertNil(stats.averagePace)
    }

    func testPaceIsMinutesPerKilometreOfMovingTime() {
        let stats = WalkStats(distance: 1000, elapsed: 900, movingTime: 600, elevationGain: 0)
        XCTAssertEqual(try XCTUnwrap(stats.averagePace), 600, accuracy: 0.001)
    }

    func testEndedAtOverridesTheLastFixForElapsed() {
        let points = TestRoute.lShaped()
        let endedAt = points[points.count - 1].timestamp.addingTimeInterval(120)
        let stats = WalkStats.compute(from: points, endedAt: endedAt)
        XCTAssertEqual(stats.elapsed, endedAt.timeIntervalSince(points[0].timestamp), accuracy: 0.001)
    }
}
