import ActivityKit
import Foundation

/// The Live Activity for a walk in progress: on the lock screen, in the
/// Dynamic Island, and -- from watchOS 11 -- in the watch's Smart Stack.
struct WalkActivityAttributes: ActivityAttributes {
    typealias ContentState = LiveWalkState

    var startedAt: Date
}
