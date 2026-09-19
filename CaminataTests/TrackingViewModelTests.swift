import CoreLocation
import XCTest
@testable import Caminata

final class TrackingViewModelTests: XCTestCase {
    private var root: URL!
    private var store: WalkStore!
    private var tracker: SpyTracker!
    private var recorder: WalkRecorder!
    private var exporter: StubExporter!
    private var model: TrackingViewModel!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("TrackingViewModelTests-\(UUID().uuidString)", isDirectory: true)
        store = WalkStore(root: root)
        tracker = SpyTracker()
        recorder = WalkRecorder(store: store, tracker: tracker)
        exporter = StubExporter()
        model = TrackingViewModel(store: store, recorder: recorder, exporter: exporter)
    }

    override func tearDownWithError() throws {
        model = nil
        try? FileManager.default.removeItem(at: root)
    }

    func testTheModelStartsIdle() {
        XCTAssertFalse(model.isRecording)
        XCTAssertTrue(model.coordinates.isEmpty)
        XCTAssertEqual(model.stats, .zero)
    }

    func testStartingPutsTheModelIntoRecording() {
        model.start()

        XCTAssertTrue(model.isRecording)
        XCTAssertEqual(tracker.startCount, 1)
    }

    func testRecordedPointsReachTheModelAsCoordinatesAndStats() {
        model.start()
        for point in TestRoute.lShaped() {
            recorder.ingest(point, now: point.timestamp)
        }

        XCTAssertEqual(model.coordinates.count, TestRoute.lShaped().count)
        XCTAssertEqual(model.stats.distance, 600, accuracy: 5)
        XCTAssertEqual(
            model.coordinates[0].latitude,
            TestRoute.origin.latitude,
            accuracy: 0.000001
        )
    }

    func testStoppingAWalkThatRecordedNothingSaysSoInsteadOfDrawingAnEmptyMap() {
        model.start()
        model.stop()

        XCTAssertFalse(model.isRecording)
        XCTAssertNil(model.export)
        XCTAssertNotNil(model.errorMessage)
    }

    func testStoppingClearsTheLiveRoute() {
        model.start()
        let point = TestRoute.lShaped()[0]
        recorder.ingest(point, now: point.timestamp)
        XCTAssertEqual(model.coordinates.count, 1)

        model.stop()

        XCTAssertTrue(model.coordinates.isEmpty)
        XCTAssertEqual(tracker.stopCount, 1)
    }

    func testExportingAFinishedWalkSurfacesItForSharing() async {
        await model.exportWalk(TestRoute.walk())

        XCTAssertEqual(exporter.exportedWalks.count, 1)
        XCTAssertNotNil(model.export)
        XCTAssertFalse(model.isExporting)
        XCTAssertNil(model.errorMessage)
    }

    func testAFailedExportIsReportedRatherThanLeavingABlankSheet() async {
        exporter.failure = CocoaError(.fileWriteUnknown)

        await model.exportWalk(TestRoute.walk())

        XCTAssertNil(model.export)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertFalse(model.isExporting)
    }

    func testTogglingSwitchesBetweenRecordingAndStopped() {
        model.toggleRecording()
        XCTAssertTrue(model.isRecording)

        model.toggleRecording()
        XCTAssertFalse(model.isRecording)
    }

    func testDeniedPermissionBlocksRecordingRatherThanFailingSilently() {
        tracker.authorizationStatus = .denied
        tracker.onAuthorizationChange?(.denied)

        XCTAssertTrue(model.permissionNeeded)

        model.start()
        XCTAssertFalse(model.isRecording)
        XCTAssertEqual(tracker.startCount, 0)
    }

    func testAnInterruptedWalkIsPickedBackUpOnAppear() throws {
        try recorder.start(at: Date().addingTimeInterval(-120))
        let point = TrackPoint(coordinate: TestRoute.origin, timestamp: Date())
        recorder.ingest(point, now: point.timestamp)

        let revivedRecorder = WalkRecorder(store: store, tracker: SpyTracker())
        let revivedModel = TrackingViewModel(
            store: store,
            recorder: revivedRecorder,
            exporter: StubExporter()
        )
        revivedModel.onAppear()

        XCTAssertTrue(revivedModel.isRecording)
        XCTAssertEqual(revivedModel.coordinates.count, 1)
    }

    func testTheHistoryModelListsFinishedWalksOnly() throws {
        try recorder.start(at: TestRoute.start)
        let point = TestRoute.lShaped()[0]
        recorder.ingest(point, now: point.timestamp)
        _ = try recorder.stop(at: TestRoute.start.addingTimeInterval(600))

        try recorder.start(at: TestRoute.start.addingTimeInterval(1200))

        let history = model.makeHistoryModel()
        history.load()

        XCTAssertEqual(history.walks.count, 1)
        XCTAssertFalse(history.walks[0].isActive)
    }
}
