import Foundation
import Observation
import WatchConnectivity

/// The watch's end of the connection to the phone.
///
/// The phone does the recording -- it has the GPS fix and the route on disk --
/// so the watch only shows what the phone last sent, runs the clock itself,
/// and asks the phone to pause or resume.
@MainActor
@Observable
final class PhoneLink: NSObject {
    private(set) var state: LiveWalkState?
    private(set) var isReachable = false
    /// Shown until the phone confirms, so a tap does not look ignored.
    private(set) var pendingCommand: WatchMessage.Command?
    private(set) var lastError: String?

    private let session: WCSession? = WCSession.isSupported() ? .default : nil

    override init() {
        super.init()
        session?.delegate = self
        session?.activate()
    }

    func send(_ command: WatchMessage.Command) {
        guard let session else { return }
        pendingCommand = command
        lastError = nil
        session.sendMessage(
            [WatchMessage.commandKey: command.rawValue],
            replyHandler: nil,
            errorHandler: { [weak self] _ in
                Task { @MainActor in
                    self?.pendingCommand = nil
                    self?.lastError = "No se pudo llegar al iPhone."
                }
            }
        )
    }

    fileprivate func receive(_ context: [String: Any]) {
        state = WatchMessage.state(from: context)
        // The phone's state has caught up with whatever was asked of it.
        if let pending = pendingCommand, let state {
            if (pending == .pause) == state.isPaused { pendingCommand = nil }
        } else {
            pendingCommand = nil
        }
    }

    fileprivate func setReachable(_ reachable: Bool) {
        isReachable = reachable
    }
}

extension PhoneLink: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        let context = session.receivedApplicationContext
        let reachable = session.isReachable
        let box = ContextBox(context)
        Task { @MainActor in
            self.receive(box.context)
            self.setReachable(reachable)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let box = ContextBox(applicationContext)
        Task { @MainActor in self.receive(box.context) }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable = session.isReachable
        Task { @MainActor in self.setReachable(reachable) }
    }
}

/// WatchConnectivity hands over `[String: Any]`, which is not Sendable; the
/// only things in it are property-list values, so moving it to the main actor
/// is safe.
private struct ContextBox: @unchecked Sendable {
    let context: [String: Any]
    init(_ context: [String: Any]) { self.context = context }
}
