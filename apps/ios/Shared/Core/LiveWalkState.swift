import Foundation

/// What a walk in progress looks like from outside the app: on the lock
/// screen, in the Dynamic Island and on the watch.
///
/// The clock is carried as the moment it would have started had it never been
/// paused, rather than as an elapsed figure. That lets the lock screen and the
/// watch run it themselves, second by second, without the app sending an
/// update every second -- and a paused walk is the same thing with the clock
/// stopped at `pausedAt`.
struct LiveWalkState: Codable, Hashable, Sendable {
    var clockStart: Date
    var pausedAt: Date?
    var distance: Double
    /// Seconds per kilometre, or nil until enough ground is covered.
    var pace: TimeInterval?
    var routeColor: String

    var isPaused: Bool { pausedAt != nil }

    init(elapsed: TimeInterval, at now: Date, pausedAt: Date?, distance: Double, pace: TimeInterval?, routeColor: String) {
        self.clockStart = (pausedAt ?? now).addingTimeInterval(-elapsed)
        self.pausedAt = pausedAt
        self.distance = distance
        self.pace = pace
        self.routeColor = routeColor
    }

    func elapsed(at now: Date = Date()) -> TimeInterval {
        max(0, (pausedAt ?? now).timeIntervalSince(clockStart))
    }
}

/// What travels between the phone and the watch, in both directions.
enum WatchMessage {
    static let stateKey = "state"
    static let commandKey = "command"

    enum Command: String {
        case pause
        case resume
    }

    /// The phone's application context: the walk, or nothing when none is
    /// running. Encoded as JSON because WatchConnectivity only carries
    /// property-list types.
    static func context(for state: LiveWalkState?) -> [String: Any] {
        // An explicit marker rather than an empty dictionary, so "no walk" is
        // a context of its own and not something that might not be delivered.
        guard let state, let data = try? JSONEncoder().encode(state) else { return ["idle": true] }
        return [stateKey: data]
    }

    static func state(from context: [String: Any]) -> LiveWalkState? {
        guard let data = context[stateKey] as? Data else { return nil }
        return try? JSONDecoder().decode(LiveWalkState.self, from: data)
    }
}
