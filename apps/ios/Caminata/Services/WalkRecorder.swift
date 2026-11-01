import CoreLocation
import Foundation

/// Owns an in-progress walk: takes fixes from the tracker, filters them, keeps
/// them in memory for the live UI, and writes each accepted one straight to disk.
@MainActor
final class WalkRecorder {
    /// A walk left open for longer than this was not interrupted, it was
    /// abandoned, so it is closed instead of silently resumed.
    static let resumeWindow: TimeInterval = 30 * 60
    static let pausedResumeWindow: TimeInterval = 12 * 60 * 60

    private let store: WalkStore
    private let tracker: LocationTracking
    private let filter: LocationPointFilter

    private(set) var metadata: WalkMetadata?
    private(set) var points: [TrackPoint] = []

    /// Set on resuming, and after a relaunch. The first fix of a new stretch
    /// is judged on its own -- age included -- instead of against the last
    /// fix before the pause, which may be far away and long ago.
    private var startsNewStretch = false

    var onChange: (() -> Void)?
    var onError: ((Error) -> Void)?
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?

    var isRecording: Bool { metadata?.isActive == true }
    var isPaused: Bool { metadata?.isPaused == true }

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
        startsNewStretch = true
        tracker.start()
        onChange?()
    }

    @discardableResult
    func stop(at date: Date = Date()) throws -> Walk? {
        guard let current = metadata else { return nil }
        tracker.stop()

        let recorded = points
        // A walk stopped while paused ended when the pause began.
        let endedAt = current.isPaused ? (current.pauseList.last?.start ?? date) : date
        var closing = current.pauseList
        if closing.last?.end == nil, !closing.isEmpty { closing[closing.count - 1].end = endedAt }
        let stats = WalkStats.compute(from: recorded, endedAt: endedAt, pauses: closing)
        let finalMetadata = try store.finish(walkID: current.id, endedAt: endedAt, stats: stats)

        metadata = nil
        points = []
        onChange?()
        return Walk(metadata: finalMetadata, points: recorded)
    }

    func pause(at date: Date = Date()) throws {
        guard let current = metadata, current.isActive, !current.isPaused else { return }
        metadata = try store.pause(walkID: current.id, at: date)
        tracker.setIdle(true)
        onChange?()
    }

    func resume(at date: Date = Date()) throws {
        guard let current = metadata, current.isPaused else { return }
        metadata = try store.resume(walkID: current.id, at: date)
        startsNewStretch = true
        tracker.setIdle(false)
        onChange?()
    }

    /// Picks a walk back up if the app was killed while recording, or closes it
    /// if too much time has passed for resuming to make sense.
    func restore(now: Date = Date()) throws {
        // The view calls this on every appearance, and picking a walk back up
        // on top of one already running would reload its points off disk and
        // start the tracker a second time.
        guard !isRecording, let active = try store.activeWalk() else { return }

        let recorded = try store.loadPoints(active.id)
        let lastActivity = [recorded.last?.timestamp, active.pauseList.last?.start, active.pauseList.last?.end]
            .compactMap { $0 }
            .max() ?? active.startedAt

        // A paused walk was put down on purpose, so it waits much longer than
        // one that simply stopped receiving fixes.
        let window = active.isPaused ? Self.pausedResumeWindow : Self.resumeWindow
        guard now.timeIntervalSince(lastActivity) <= window else {
            let endedAt = active.isPaused ? (active.pauseList.last?.start ?? lastActivity) : lastActivity
            var closing = active.pauseList
            if closing.last?.end == nil, !closing.isEmpty { closing[closing.count - 1].end = endedAt }
            let stats = WalkStats.compute(from: recorded, endedAt: endedAt, pauses: closing)
            try store.finish(walkID: active.id, endedAt: endedAt, stats: stats)
            return
        }

        metadata = active
        points = recorded
        // A relaunch without a pause in between is the same stretch: its first
        // fix is still checked against the last one, so a bad fix cannot add a
        // jump. Resuming is what starts a new stretch.
        startsNewStretch = false
        tracker.start()
        tracker.setIdle(active.isPaused)
        onChange?()
    }

    // MARK: - Ingestion

    /// Exposed so the filtering and accumulation rules can be exercised with
    /// synthetic points, without CoreLocation in the loop.
    @discardableResult
    func ingest(_ candidate: TrackPoint, now: Date = Date()) -> FilterDecision {
        guard let metadata else { return .reject(.invalidFix) }
        guard !metadata.isPaused else { return .reject(.paused) }

        let previous = startsNewStretch ? nil : points.last
        let decision = filter.evaluate(candidate, previous: previous, now: now)
        guard decision.isAccepted else { return decision }

        startsNewStretch = false
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
