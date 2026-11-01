import Foundation

/// Tells everything outside the app about the walk in progress -- the lock
/// screen and the watch -- and hears back from the watch.
@MainActor
protocol WalkBroadcasting: AnyObject {
    /// Nil when no walk is running, which ends the Live Activity and clears
    /// the watch.
    func publish(_ state: LiveWalkState?, startedAt: Date?)
    var onCommand: ((WatchMessage.Command) -> Void)? { get set }
}

@MainActor
final class LiveBroadcaster: WalkBroadcasting {
    private let activity = WalkLiveActivity()
    private let watch = WatchLink()

    var onCommand: ((WatchMessage.Command) -> Void)? {
        get { watch.onCommand }
        set { watch.onCommand = newValue }
    }

    func publish(_ state: LiveWalkState?, startedAt: Date?) {
        activity.publish(state, startedAt: startedAt)
        watch.publish(state)
    }
}
