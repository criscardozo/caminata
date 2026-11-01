import Foundation
import WatchConnectivity

/// The phone's end of the connection to the watch app.
///
/// The walk travels as the application context, which WatchConnectivity
/// keeps and hands to the watch app whenever it next runs, so a watch that
/// was out of range or asleep still opens on the current state. The watch
/// sends back pause and resume as messages.
@MainActor
final class WatchLink: NSObject {
    /// The watch runs the clock itself, so after the first state the context
    /// only needs refreshing for the distance and pace.
    static let minimumInterval: TimeInterval = 10

    var onCommand: ((WatchMessage.Command) -> Void)?

    private let session: WCSession? = WCSession.isSupported() ? .default : nil
    private var lastSent: LiveWalkState?
    private var lastSentAt: Date = .distantPast
    private var pending: LiveWalkState??
    /// The first publish always goes out, even "no walk": a watch left showing
    /// a walk from before a relaunch has to be told it is over.
    private var hasSent = false

    override init() {
        super.init()
        session?.delegate = self
        session?.activate()
    }

    func publish(_ state: LiveWalkState?) {
        let changedShape = (lastSent == nil) != (state == nil) || lastSent?.isPaused != state?.isPaused
        let due = Date().timeIntervalSince(lastSentAt) >= Self.minimumInterval
        guard !hasSent || (state != lastSent && (changedShape || due)) else { return }

        guard let session, session.activationState == .activated else {
            pending = .some(state)
            return
        }
        guard session.isPaired, session.isWatchAppInstalled else { return }

        lastSent = state
        lastSentAt = Date()
        hasSent = true
        try? session.updateApplicationContext(WatchMessage.context(for: state))
    }

    private func flushPending() {
        guard let state = pending else { return }
        pending = nil
        hasSent = false
        publish(state)
    }
}

extension WatchLink: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in self.flushPending() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    /// Called when the phone switches to a different watch; the new one needs
    /// a session of its own.
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let raw = message[WatchMessage.commandKey] as? String,
              let command = WatchMessage.Command(rawValue: raw) else { return }
        Task { @MainActor in self.onCommand?(command) }
    }
}
