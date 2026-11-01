import XCTest
@testable import Caminata

/// Pausing has to take the paused time out of the clock and the paused gap out
/// of the route: whatever happened between pausing and resuming -- a coffee,
/// a bus -- is not part of the walk.
final class PauseStatsTests: XCTestCase {
    private let t0 = TestRoute.start

    private func point(north: Double, at seconds: TimeInterval) -> TrackPoint {
        TrackPoint(
            coordinate: TestRoute.offset(TestRoute.origin, northMetres: north, eastMetres: 0),
            altitude: 25,
            timestamp: t0.addingTimeInterval(seconds)
        )
    }

    func testPausedTimeIsLeftOutOfTheClock() {
        let pauses = [WalkPause(start: t0.addingTimeInterval(600), end: t0.addingTimeInterval(900))]
        let active = WalkStats.activeDuration(from: t0, to: t0.addingTimeInterval(1200), pauses: pauses)
        XCTAssertEqual(active, 900, accuracy: 0.001)
    }

    func testAnOpenPauseStopsTheClockWhereItBegan() {
        let pauses = [WalkPause(start: t0.addingTimeInterval(600), end: nil)]
        for later in [700.0, 3600, 7200] {
            let active = WalkStats.activeDuration(from: t0, to: t0.addingTimeInterval(later), pauses: pauses)
            XCTAssertEqual(active, 600, accuracy: 0.001, "the clock moved during the pause at \(later)s")
        }
    }

    /// Two hundred metres walked, then a pause during which the phone moved a
    /// kilometre, then a hundred more. Only the walking counts.
    func testDistanceCoveredDuringAPauseIsNotWalked() {
        let points = [
            point(north: 0, at: 0), point(north: 100, at: 80), point(north: 200, at: 160),
            point(north: 1200, at: 1000), point(north: 1300, at: 1080)
        ]
        let pauses = [WalkPause(start: t0.addingTimeInterval(200), end: t0.addingTimeInterval(950))]

        let stats = WalkStats.compute(from: points, endedAt: t0.addingTimeInterval(1080), pauses: pauses)

        XCTAssertEqual(stats.distance, 300, accuracy: 3)
        XCTAssertEqual(stats.elapsed, 1080 - 750, accuracy: 0.001)
    }

    func testAWalkIsCutIntoStretchesAtItsPauses() {
        let points = [point(north: 0, at: 0), point(north: 100, at: 80), point(north: 1200, at: 1000), point(north: 1300, at: 1080)]
        let pauses = [WalkPause(start: t0.addingTimeInterval(200), end: t0.addingTimeInterval(950))]

        let segments = Walk.segments(of: points, pauses: pauses)

        XCTAssertEqual(segments.map(\.count), [2, 2])
    }

    func testAWalkNeverPausedIsOneStretch() {
        let points = TestRoute.lShaped()
        XCTAssertEqual(Walk.segments(of: points, pauses: []).count, 1)
    }

    /// The upload carries the stretches as break indices beside the flat
    /// route, which is how the web knows where not to draw.
    func testTheCloudCopyMarksWhereEachStretchBegins() throws {
        let points = [point(north: 0, at: 0), point(north: 100, at: 80), point(north: 1200, at: 1000), point(north: 1300, at: 1080)]
        var metadata = WalkMetadata(id: UUID(), startedAt: t0, endedAt: t0.addingTimeInterval(1080))
        metadata.pauses = [WalkPause(start: t0.addingTimeInterval(200), end: t0.addingTimeInterval(950))]

        let cloud = try XCTUnwrap(CloudWalk(walk: Walk(metadata: metadata, points: points)))

        XCTAssertEqual(cloud.breaks, [2])
        XCTAssertEqual(cloud.segments.map(\.count), [2, 2])
    }

    /// A walk written before pausing existed has no `pauses` key at all.
    func testAWalkFromBeforePausingStillDecodes() throws {
        let json = #"{"id":"6B1C6A3E-6A1B-4C83-9E5B-6E3B9F2B1A11","startedAt":1700000000}"#
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let metadata = try decoder.decode(WalkMetadata.self, from: Data(json.utf8))
        XCTAssertTrue(metadata.pauseList.isEmpty)
        XCTAssertFalse(metadata.isPaused)
    }
}

@MainActor
final class PauseRecordingTests: XCTestCase {
    private var root: URL!
    private var store: WalkStore!
    private var tracker: SpyTracker!
    private var recorder: WalkRecorder!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PauseRecordingTests-\(UUID().uuidString)", isDirectory: true)
        store = WalkStore(root: root)
        tracker = SpyTracker()
        recorder = WalkRecorder(store: store, tracker: tracker)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func fix(north: Double, at date: Date) -> TrackPoint {
        TrackPoint(coordinate: TestRoute.offset(TestRoute.origin, northMetres: north, eastMetres: 0), timestamp: date)
    }

    func testFixesThatArriveWhilePausedAreNotRecorded() throws {
        let t0 = TestRoute.start
        try recorder.start(at: t0)
        recorder.ingest(fix(north: 0, at: t0), now: t0)
        try recorder.pause(at: t0.addingTimeInterval(10))

        let decision = recorder.ingest(fix(north: 50, at: t0.addingTimeInterval(40)), now: t0.addingTimeInterval(40))

        XCTAssertEqual(decision, .reject(.paused))
        XCTAssertEqual(recorder.points.count, 1)
    }

    /// The tracker is not stopped -- that would let iOS suspend the app -- it
    /// is turned down to its cheapest setting, and back up on resuming.
    func testPausingIdlesTheTrackerInsteadOfStoppingIt() throws {
        try recorder.start(at: TestRoute.start)
        try recorder.pause(at: TestRoute.start.addingTimeInterval(10))
        try recorder.resume(at: TestRoute.start.addingTimeInterval(20))

        XCTAssertEqual(tracker.idleChanges, [true, false])
        XCTAssertEqual(tracker.stopCount, 0)
    }

    /// After resuming somewhere far away, the first fix would fail the speed
    /// check against the last fix before the pause. It starts a new stretch.
    func testTheFirstFixAfterResumingIsNotJudgedAgainstTheOneBeforeThePause() throws {
        let t0 = TestRoute.start
        try recorder.start(at: t0)
        recorder.ingest(fix(north: 0, at: t0), now: t0)
        try recorder.pause(at: t0.addingTimeInterval(10))
        // Five kilometres in two minutes: a bus, not a teleport.
        let resumed = t0.addingTimeInterval(130)
        try recorder.resume(at: resumed)

        let decision = recorder.ingest(fix(north: 5000, at: resumed), now: resumed)

        XCTAssertEqual(decision, .accept)
        XCTAssertEqual(recorder.currentWalk?.stats.distance ?? -1, 0, accuracy: 0.001)
    }

    /// ...but a stale cached fix handed over the moment updates speed back up
    /// is still turned away, as it is at the very start of a walk.
    func testAStaleFixRightAfterResumingIsRejected() throws {
        let t0 = TestRoute.start
        try recorder.start(at: t0)
        recorder.ingest(fix(north: 0, at: t0), now: t0)
        try recorder.pause(at: t0.addingTimeInterval(10))
        try recorder.resume(at: t0.addingTimeInterval(600))

        let cached = fix(north: 20, at: t0.addingTimeInterval(15))
        guard case .reject(.stale) = recorder.ingest(cached, now: t0.addingTimeInterval(600)) else {
            return XCTFail("a fix from before resuming should have been refused as stale")
        }
    }

    func testStoppingWhilePausedEndsTheWalkWhenThePauseBegan() throws {
        let t0 = TestRoute.start
        try recorder.start(at: t0)
        recorder.ingest(fix(north: 0, at: t0), now: t0)
        recorder.ingest(fix(north: 100, at: t0.addingTimeInterval(80)), now: t0.addingTimeInterval(80))
        try recorder.pause(at: t0.addingTimeInterval(100))

        let walk = try XCTUnwrap(recorder.stop(at: t0.addingTimeInterval(3600)))

        XCTAssertEqual(walk.endedAt, t0.addingTimeInterval(100))
        XCTAssertEqual(walk.stats.elapsed, 100, accuracy: 0.001)
        XCTAssertFalse(walk.metadata.isPaused)
    }

    func testAWalkKilledWhilePausedComesBackPaused() throws {
        let t0 = Date().addingTimeInterval(-3 * 3600)
        try recorder.start(at: t0)
        recorder.ingest(fix(north: 0, at: t0), now: t0)
        try recorder.pause(at: t0.addingTimeInterval(60))

        let revived = WalkRecorder(store: store, tracker: tracker)
        // Three hours later is past the ordinary resume window, but a pause is
        // deliberate and waits longer.
        try revived.restore(now: Date())

        XCTAssertTrue(revived.isRecording)
        XCTAssertTrue(revived.isPaused)
        XCTAssertEqual(tracker.idleChanges.last, true)
    }
}

@MainActor
final class PauseViewModelTests: XCTestCase {
    private var root: URL!
    private var store: WalkStore!
    private var recorder: WalkRecorder!
    private var broadcaster: SpyBroadcaster!
    private var model: TrackingViewModel!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PauseViewModelTests-\(UUID().uuidString)", isDirectory: true)
        store = WalkStore(root: root)
        recorder = WalkRecorder(store: store, tracker: SpyTracker())
        broadcaster = SpyBroadcaster()
        model = TrackingViewModel(store: store, recorder: recorder, exporter: StubExporter(), broadcaster: broadcaster)
    }

    override func tearDown() async throws {
        model = nil
        try? FileManager.default.removeItem(at: root)
    }

    func testTheLockScreenAndWatchHearAboutTheWalkAndItsPause() {
        model.start()
        XCTAssertNotNil(broadcaster.last)
        XCTAssertEqual(broadcaster.last?.isPaused, false)

        model.pause()
        XCTAssertEqual(broadcaster.last?.isPaused, true)

        model.resume()
        XCTAssertEqual(broadcaster.last?.isPaused, false)

        model.stop()
        XCTAssertNil(broadcaster.last, "stopping must end the Live Activity and clear the watch")
    }

    func testTheWatchCanPauseAndResume() {
        model.start()

        broadcaster.onCommand?(.pause)
        XCTAssertTrue(model.isPaused)

        broadcaster.onCommand?(.resume)
        XCTAssertFalse(model.isPaused)
    }
}

final class LiveWalkStateTests: XCTestCase {
    /// The lock screen runs the clock itself from clockStart, so a state built
    /// at one moment has to read the same elapsed time at any later one.
    func testTheClockKeepsRunningWithoutUpdates() {
        let now = Date()
        let state = LiveWalkState(elapsed: 125, at: now, pausedAt: nil, distance: 0, pace: nil, routeColor: "#D9293D")
        XCTAssertEqual(state.elapsed(at: now.addingTimeInterval(60)), 185, accuracy: 0.001)
    }

    func testAPausedClockStaysPut() {
        let pausedAt = Date()
        let state = LiveWalkState(elapsed: 125, at: pausedAt.addingTimeInterval(300), pausedAt: pausedAt, distance: 0, pace: nil, routeColor: "#D9293D")
        XCTAssertEqual(state.elapsed(at: pausedAt.addingTimeInterval(3600)), 125, accuracy: 0.001)
    }

    func testTheStateSurvivesTheTripToTheWatch() {
        let state = LiveWalkState(elapsed: 42, at: Date(), pausedAt: nil, distance: 812, pace: 540, routeColor: "#0E9F6E")
        XCTAssertEqual(WatchMessage.state(from: WatchMessage.context(for: state)), state)
        XCTAssertNil(WatchMessage.state(from: WatchMessage.context(for: nil)))
    }
}
