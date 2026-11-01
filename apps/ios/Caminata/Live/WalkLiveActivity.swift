// ActivityKit has not marked Activity as Sendable, though Apple documents it as
// safe to use from any thread; this keeps the update and end calls quiet.
@preconcurrency import ActivityKit
import Foundation

/// The Live Activity on the lock screen and in the Dynamic Island.
///
/// The clock runs by itself on the lock screen, so the activity is only
/// updated when something it shows has moved on: on pause and resume at once,
/// otherwise at most every `minimumInterval` for the distance and pace. That
/// keeps well inside the update budget iOS gives an app in the background.
@MainActor
final class WalkLiveActivity {
    static let minimumInterval: TimeInterval = 15

    private var activity: Activity<WalkActivityAttributes>?
    private var lastSent: LiveWalkState?
    private var lastSentAt: Date = .distantPast

    init() {
        // An activity from before a relaunch is still on the lock screen; pick
        // it up rather than starting a second one beside it.
        activity = Activity<WalkActivityAttributes>.activities.first
    }

    func publish(_ state: LiveWalkState?, startedAt: Date?) {
        guard let state, let startedAt else {
            end()
            return
        }

        guard let activity else {
            start(state, startedAt: startedAt)
            return
        }

        let pauseChanged = lastSent?.isPaused != state.isPaused
        let due = Date().timeIntervalSince(lastSentAt) >= Self.minimumInterval
        guard state != lastSent, pauseChanged || due else { return }

        lastSent = state
        lastSentAt = Date()
        Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    private func start(_ state: LiveWalkState, startedAt: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        do {
            activity = try Activity.request(
                attributes: WalkActivityAttributes(startedAt: startedAt),
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
            lastSent = state
            lastSentAt = Date()
        } catch {
            // The walk records the same without it; the lock screen is a
            // convenience, not a requirement.
        }
    }

    private func end() {
        let ending = Activity<WalkActivityAttributes>.activities
        activity = nil
        lastSent = nil
        guard !ending.isEmpty else { return }
        Task {
            for activity in ending {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
