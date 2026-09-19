import CoreLocation
import Foundation

/// Owns an in-progress walk: takes fixes from the tracker, filters them, keeps
/// them in memory for the live UI, and writes each accepted one straight to disk.
final class WalkRecorder {
    /// A walk left open for longer than this was not interrupted, it was
    /// abandoned, so it is closed instead of silently resumed.
    static let resumeWindow: TimeInterval = 30 * 60

    private let store: WalkStore
    private let tracker: LocationTracking
    private let filter: LocationPointFilter

    private(set) var metadata: WalkMetadata?
    private(set) var points: [TrackPoint] = []

    var onChange: (() -> Void)?
    var onError: ((Error) -> Void)?
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?

    var isRecording: Bool { metadata?.isActive == true }

    var currentWalk: Walk? {
        guard let metadata else { return nil }
        return Walk(metadata: metadata, points: points)
    }

    var authorizationStatus: CLAuthorizationStatus { tracker.authorizationStatus }

    init(
        store: WalkStore,
        tracker: LocationTracking = LocationTracker(),
        filter: LocationPointFilter = LocationPointFilter()
    ) {
        self.store = store
        self.tracker = tracker
        self.filter = filter

        tracker.onLocations = { [weak self] locations in
            guard let self else { return }
            let now = Date()
            for location in locations {
                self.ingest(TrackPoint(location), now: now)
            }
        }
        tracker.onAuthorizationChange = { [weak self] status in
            self?.onAuthorizationChange?(status)
        }
        tracker.onFailure = { [weak self] error in
            self?.onError?(error)
        }
    }

    func requestAuthorization() {
        tracker.requestAuthorization()
    }

    // MARK: - Lifecycle

    func start(at date: Date = Date()) throws {
        guard !isRecording else { return }
        metadata = try store.createWalk(startedAt: date)
        points = []
        tracker.start()
        onChange?()
    }

    @discardableResult
    func stop(at date: Date = Date()) throws -> Walk? {
        guard let current = metadata else { return nil }
        tracker.stop()

        let recorded = points
        let stats = WalkStats.compute(from: recorded, endedAt: date)
        let finalMetadata = try store.finish(walkID: current.id, endedAt: date, stats: stats)

        metadata = nil
        points = []
        onChange?()
        return Walk(metadata: finalMetadata, points: recorded)
    }

    /// Picks a walk back up if the app was killed while recording, or closes it
    /// if too much time has passed for resuming to make sense.
    func restore(now: Date = Date()) throws {
        guard let active = try store.activeWalk() else { return }

        let recorded = try store.loadPoints(active.id)
        let lastActivity = recorded.last?.timestamp ?? active.startedAt

        guard now.timeIntervalSince(lastActivity) <= Self.resumeWindow else {
            let stats = WalkStats.compute(from: recorded, endedAt: lastActivity)
            try store.finish(walkID: active.id, endedAt: lastActivity, stats: stats)
            return
        }

        metadata = active
        points = recorded
        tracker.start()
        onChange?()
    }

    // MARK: - Ingestion

    /// Exposed so the filtering and accumulation rules can be exercised with
    /// synthetic points, without CoreLocation in the loop.
    @discardableResult
    func ingest(_ candidate: TrackPoint, now: Date = Date()) -> FilterDecision {
        guard let metadata else { return .reject(.invalidFix) }

        let decision = filter.evaluate(candidate, previous: points.last, now: now)
        guard decision.isAccepted else { return decision }

        points.append(candidate)
        do {
            try store.append(candidate, to: metadata.id)
        } catch {
            onError?(error)
        }
        onChange?()
        return decision
    }
}
