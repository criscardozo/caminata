import CoreLocation
import XCTest
@testable import Caminata

private final class SpyTracker: LocationTracking {
    var authorizationStatus: CLAuthorizationStatus = .authorizedWhenInUse
    var onLocations: (([CLLocation]) -> Void)?
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?
    var onFailure: ((Error) -> Void)?

    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var authorizationRequests = 0

    func requestAuthorization() { authorizationRequests += 1 }
    func start() { startCount += 1 }
    func stop() { stopCount += 1 }
}

final class WalkRecorderTests: XCTestCase {
    private var root: URL!
    private var store: WalkStore!
    private var tracker: SpyTracker!
    private var recorder: WalkRecorder!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("WalkRecorderTests-\(UUID().uuidString)", isDirectory: true)
        store = WalkStore(root: root)
        tracker = SpyTracker()
        recorder = WalkRecorder(store: store, tracker: tracker)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func feed(_ points: [TrackPoint]) {
        for point in points {
            recorder.ingest(point, now: point.timestamp)
        }
    }

    func testStartingBeginsAWalkAndTheTracker() throws {
        try recorder.start(at: TestRoute.start)

        XCTAssertTrue(recorder.isRecording)
        XCTAssertEqual(tracker.startCount, 1)
        XCTAssertEqual(try store.activeWalk()?.startedAt, TestRoute.start)
    }

    func testPointsArrivingBeforeAWalkStartsAreIgnored() {
        XCTAssertFalse(recorder.ingest(TestRoute.lShaped()[0], now: TestRoute.start).isAccepted)
        XCTAssertTrue(recorder.points.isEmpty)
    }

    func testAcceptedPointsAreWrittenToDiskAsTheyArrive() throws {
        try recorder.start(at: TestRoute.start)
        let points = TestRoute.lShaped()
        feed(points)

        XCTAssertEqual(recorder.points.count, points.count)
        let walkID = try XCTUnwrap(recorder.metadata?.id)
        // Not at stop time: on disk already, mid-walk.
        XCTAssertEqual(try store.loadPoints(walkID).count, points.count)
    }

    func testRejectedPointsAreNeitherKeptNorStored() throws {
        try recorder.start(at: TestRoute.start)
        let first = TestRoute.lShaped()[0]
        recorder.ingest(first, now: first.timestamp)

        let jitter = TrackPoint(
            coordinate: TestRoute.offset(TestRoute.origin, northMetres: 0.5, eastMetres: 0),
            timestamp: first.timestamp.addingTimeInterval(2)
        )
        let decision = recorder.ingest(jitter, now: jitter.timestamp)

        XCTAssertFalse(decision.isAccepted)
        XCTAssertEqual(recorder.points, [first])
        XCTAssertEqual(try store.loadPoints(XCTUnwrap(recorder.metadata?.id)).count, 1)
    }

    func testStoppingReturnsTheFinishedWalkWithItsStats() throws {
        try recorder.start(at: TestRoute.start)
        let points = TestRoute.lShaped()
        feed(points)

        let endedAt = points[points.count - 1].timestamp
        let walk = try XCTUnwrap(recorder.stop(at: endedAt))

        XCTAssertFalse(recorder.isRecording)
        XCTAssertEqual(tracker.stopCount, 1)
        XCTAssertEqual(walk.points.count, points.count)
        XCTAssertEqual(walk.stats.distance, 600, accuracy: 5)
        XCTAssertEqual(try XCTUnwrap(walk.metadata.distance), 600, accuracy: 5)
        XCTAssertNil(try store.activeWalk())
    }

    func testStoppingWhenNothingIsRecordingIsHarmless() throws {
        XCTAssertNil(try recorder.stop())
        XCTAssertEqual(tracker.stopCount, 0)
    }

    func testLocationsFromTheTrackerAreRecorded() throws {
        try recorder.start()

        let now = Date()
        tracker.onLocations?([
            CLLocation(
                coordinate: CLLocationCoordinate2D(
                    latitude: TestRoute.origin.latitude,
                    longitude: TestRoute.origin.longitude
                ),
                altitude: 30,
                horizontalAccuracy: 5,
                verticalAccuracy: 5,
                course: 0,
                speed: 1.3,
                timestamp: now
            )
        ])

        XCTAssertEqual(recorder.points.count, 1)
        XCTAssertEqual(recorder.points[0].altitude, 30)
        XCTAssertEqual(recorder.points[0].coordinate.latitude, TestRoute.origin.latitude, accuracy: 0.000001)
    }

    func testAWalkInterruptedMomentsAgoIsPickedBackUp() throws {
        try recorder.start(at: TestRoute.start)
        let points = Array(TestRoute.lShaped().prefix(10))
        feed(points)

        // A fresh recorder stands in for the app being relaunched.
        let revived = WalkRecorder(store: store, tracker: tracker)
        try revived.restore(now: points[points.count - 1].timestamp.addingTimeInterval(60))

        XCTAssertTrue(revived.isRecording)
        XCTAssertEqual(revived.points.count, points.count)
    }

    func testAWalkAbandonedHoursAgoIsClosedInsteadOfResumed() throws {
        try recorder.start(at: TestRoute.start)
        let points = Array(TestRoute.lShaped().prefix(10))
        feed(points)

        let revived = WalkRecorder(store: store, tracker: tracker)
        try revived.restore(now: points[points.count - 1].timestamp.addingTimeInterval(6 * 3600))

        XCTAssertFalse(revived.isRecording)
        XCTAssertNil(try store.activeWalk())
        XCTAssertEqual(try store.listWalks().count, 1)
    }

    func testRestoringWithNothingInProgressDoesNothing() throws {
        try recorder.restore()
        XCTAssertFalse(recorder.isRecording)
        XCTAssertEqual(tracker.startCount, 0)
    }

    func testChangesAreAnnouncedSoTheUICanFollowAlong() throws {
        var updates = 0
        recorder.onChange = { updates += 1 }

        try recorder.start(at: TestRoute.start)
        feed(Array(TestRoute.lShaped().prefix(3)))

        // One for the start, one per accepted point.
        XCTAssertEqual(updates, 4)
    }
}
