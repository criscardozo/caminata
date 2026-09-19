import XCTest
@testable import Caminata

@MainActor
final class WalkUploaderTests: XCTestCase {
    private var root: URL!
    private var store: WalkStore!
    private var sync: StubSync!
    private var uploader: WalkUploader!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("WalkUploaderTests-\(UUID().uuidString)", isDirectory: true)
        store = WalkStore(root: root)
        sync = StubSync()
        uploader = WalkUploader(store: store, sync: sync)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
    }

    /// Records a finished walk the way the recorder would, and hands it back.
    @discardableResult
    private func storeFinishedWalk(startedAt: Date = TestRoute.start) throws -> Walk {
        let points = TestRoute.lShaped()
        var metadata = try store.createWalk(startedAt: startedAt)
        for point in points {
            try store.append(point, to: metadata.id)
        }
        let endedAt = points[points.count - 1].timestamp
        metadata = try store.finish(
            walkID: metadata.id,
            endedAt: endedAt,
            stats: WalkStats.compute(from: points, endedAt: endedAt)
        )
        return Walk(metadata: metadata, points: points)
    }

    func testAnUploadedWalkIsMarkedSoItIsNotSentTwice() throws {
        let walk = try storeFinishedWalk()

        let sent = runUpload(walk)

        XCTAssertTrue(sent)
        XCTAssertEqual(sync.uploaded.count, 1)
        XCTAssertNotNil(try store.loadMetadata(walk.id).uploadedAt)
        XCTAssertTrue(uploader.pending().isEmpty)
    }

    func testAFailedUploadLeavesTheWalkQueuedRatherThanLosingIt() throws {
        let walk = try storeFinishedWalk()
        sync.failure = URLError(.notConnectedToInternet)

        let sent = runUpload(walk)

        XCTAssertFalse(sent)
        XCTAssertNil(try store.loadMetadata(walk.id).uploadedAt)
        XCTAssertEqual(uploader.pending().count, 1)
    }

    func testWalksRecordedWhileSignedOutAreSentOnceSigningInMakesItPossible() throws {
        try storeFinishedWalk(startedAt: TestRoute.start)
        try storeFinishedWalk(startedAt: TestRoute.start.addingTimeInterval(7200))
        sync.canUpload = false

        runPending()
        XCTAssertTrue(sync.uploaded.isEmpty)
        XCTAssertEqual(uploader.pending().count, 2)

        sync.canUpload = true
        runPending()

        XCTAssertEqual(sync.uploaded.count, 2)
        XCTAssertTrue(uploader.pending().isEmpty)
    }

    func testTheBacklogStopsAtTheFirstFailureInsteadOfHammeringADeadConnection() throws {
        try storeFinishedWalk(startedAt: TestRoute.start)
        try storeFinishedWalk(startedAt: TestRoute.start.addingTimeInterval(7200))
        sync.failure = URLError(.timedOut)

        runPending()

        XCTAssertTrue(sync.uploaded.isEmpty)
        XCTAssertEqual(uploader.pending().count, 2)
    }

    func testAWalkStillInProgressIsNotUploaded() throws {
        _ = try store.createWalk(startedAt: TestRoute.start)
        XCTAssertTrue(uploader.pending().isEmpty)

        runPending()
        XCTAssertTrue(sync.uploaded.isEmpty)
    }

    func testThePendingCountIsPublishedForTheUI() throws {
        try storeFinishedWalk()
        var notifications = 0
        uploader.onChange = { notifications += 1 }

        uploader.refreshPendingCount()

        XCTAssertEqual(uploader.pendingCount, 1)
        XCTAssertEqual(notifications, 1)
    }

    // MARK: - Helpers

    private func runUpload(_ walk: Walk) -> Bool {
        var sent = false
        let done = expectation(description: "upload")
        Task { sent = await uploader.upload(walk); done.fulfill() }
        wait(for: [done], timeout: 5)
        return sent
    }

    private func runPending() {
        let done = expectation(description: "pending")
        Task { await uploader.uploadPending(); done.fulfill() }
        wait(for: [done], timeout: 5)
    }
}
