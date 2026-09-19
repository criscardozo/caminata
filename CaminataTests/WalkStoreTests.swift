import XCTest
@testable import Caminata

final class WalkStoreTests: XCTestCase {
    private var root: URL!
    private var store: WalkStore!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("WalkStoreTests-\(UUID().uuidString)", isDirectory: true)
        store = WalkStore(root: root)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testListingAnEmptyStoreReturnsNothing() throws {
        XCTAssertTrue(try store.listWalks().isEmpty)
    }

    func testAppendedPointsSurviveARoundTrip() throws {
        let metadata = try store.createWalk(startedAt: TestRoute.start)
        let points = TestRoute.lShaped()
        for point in points {
            try store.append(point, to: metadata.id)
        }

        XCTAssertEqual(try store.loadPoints(metadata.id), points)
    }

    func testFinishingAWalkRecordsItsSummary() throws {
        let metadata = try store.createWalk(startedAt: TestRoute.start)
        let points = TestRoute.lShaped()
        for point in points {
            try store.append(point, to: metadata.id)
        }

        let endedAt = TestRoute.start.addingTimeInterval(600)
        let stats = WalkStats.compute(from: points, endedAt: endedAt)
        let finished = try store.finish(walkID: metadata.id, endedAt: endedAt, stats: stats)

        XCTAssertEqual(finished.endedAt, endedAt)
        XCTAssertEqual(try XCTUnwrap(finished.distance), stats.distance, accuracy: 0.001)
        XCTAssertFalse(try store.loadMetadata(metadata.id).isActive)
    }

    func testAHalfWrittenFinalLineIsDiscardedRatherThanLosingTheWalk() throws {
        let metadata = try store.createWalk(startedAt: TestRoute.start)
        let points = Array(TestRoute.lShaped().prefix(3))
        for point in points {
            try store.append(point, to: metadata.id)
        }

        // Simulate the app being killed part way through writing a fourth point.
        let pointsFile = root
            .appendingPathComponent(metadata.id.uuidString)
            .appendingPathComponent("points.jsonl")
        let handle = try FileHandle(forWritingTo: pointsFile)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(#"{"coordinate":{"latitude":-34.60"#.utf8))
        try handle.close()

        XCTAssertEqual(try store.loadPoints(metadata.id), points)
    }

    func testAnUnfinishedWalkIsReportedAsActive() throws {
        let metadata = try store.createWalk(startedAt: TestRoute.start)
        XCTAssertEqual(try store.activeWalk()?.id, metadata.id)

        try store.finish(walkID: metadata.id, endedAt: TestRoute.start.addingTimeInterval(60))
        XCTAssertNil(try store.activeWalk())
    }

    func testWalksAreListedNewestFirst() throws {
        let older = try store.createWalk(startedAt: TestRoute.start)
        let newer = try store.createWalk(startedAt: TestRoute.start.addingTimeInterval(3600))

        XCTAssertEqual(try store.listWalks().map(\.id), [newer.id, older.id])
    }

    func testDeletingAWalkRemovesItCompletely() throws {
        let metadata = try store.createWalk(startedAt: TestRoute.start)
        try store.append(TestRoute.lShaped()[0], to: metadata.id)

        try store.delete(walkID: metadata.id)

        XCTAssertTrue(try store.listWalks().isEmpty)
        XCTAssertThrowsError(try store.loadMetadata(metadata.id))
    }

    func testLoadingAnUnknownWalkThrows() {
        XCTAssertThrowsError(try store.loadMetadata(UUID())) { error in
            XCTAssertNotNil(error as? WalkStore.StoreError)
        }
    }
}
