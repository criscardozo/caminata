import XCTest
@testable import Caminata

final class LocationPointFilterTests: XCTestCase {
    private let filter = LocationPointFilter()
    private let now = TestRoute.start

    private func point(
        northMetres: Double = 0,
        accuracy: Double = 5,
        secondsAgo: TimeInterval = 0
    ) -> TrackPoint {
        TrackPoint(
            coordinate: TestRoute.offset(TestRoute.origin, northMetres: northMetres, eastMetres: 0),
            horizontalAccuracy: accuracy,
            timestamp: now.addingTimeInterval(-secondsAgo)
        )
    }

    func testFirstPointIsAcceptedWithNoPredecessor() {
        XCTAssertEqual(filter.evaluate(point(), previous: nil, now: now), .accept)
    }

    func testNegativeAccuracyIsRejectedAsAnInvalidFix() {
        let decision = filter.evaluate(point(accuracy: -1), previous: nil, now: now)
        XCTAssertEqual(decision, .reject(.invalidFix))
    }

    func testPoorAccuracyIsRejected() {
        let decision = filter.evaluate(point(accuracy: 120), previous: nil, now: now)
        XCTAssertEqual(decision, .reject(.poorAccuracy(120)))
    }

    func testAccuracyAtTheLimitIsAccepted() {
        XCTAssertEqual(filter.evaluate(point(accuracy: 50), previous: nil, now: now), .accept)
    }

    func testStaleFixesAreRejected() {
        let decision = filter.evaluate(point(secondsAgo: 30), previous: nil, now: now)
        XCTAssertEqual(decision, .reject(.stale(30)))
    }

    func testPointsTooCloseToThePreviousOneAreRejected() {
        let previous = point()
        let candidate = TrackPoint(
            coordinate: TestRoute.offset(TestRoute.origin, northMetres: 1, eastMetres: 0),
            timestamp: now.addingTimeInterval(1)
        )

        guard case .reject(.tooClose) = filter.evaluate(candidate, previous: previous, now: now.addingTimeInterval(1)) else {
            return XCTFail("Expected a tooClose rejection")
        }
    }

    func testAStepFurtherThanTheMinimumIsAccepted() {
        let previous = point()
        let candidate = TrackPoint(
            coordinate: TestRoute.offset(TestRoute.origin, northMetres: 10, eastMetres: 0),
            timestamp: now.addingTimeInterval(8)
        )
        XCTAssertEqual(
            filter.evaluate(candidate, previous: previous, now: now.addingTimeInterval(8)),
            .accept
        )
    }

    func testTeleportingFixesAreRejected() {
        let previous = point()
        // 5 km in one second.
        let candidate = TrackPoint(
            coordinate: TestRoute.offset(TestRoute.origin, northMetres: 5000, eastMetres: 0),
            timestamp: now.addingTimeInterval(1)
        )

        guard case .reject(.implausibleSpeed) = filter.evaluate(
            candidate,
            previous: previous,
            now: now.addingTimeInterval(1)
        ) else {
            return XCTFail("Expected an implausibleSpeed rejection")
        }
    }

    func testAWholeRealisticRouteIsAcceptedEndToEnd() {
        var previous: TrackPoint?
        var accepted = 0
        for candidate in TestRoute.lShaped() {
            if filter.evaluate(candidate, previous: previous, now: candidate.timestamp).isAccepted {
                accepted += 1
                previous = candidate
            }
        }
        XCTAssertEqual(accepted, TestRoute.lShaped().count)
    }
}
