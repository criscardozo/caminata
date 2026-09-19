import Foundation

/// Gets finished walks to Firestore, and keeps trying.
///
/// A walk is stopped wherever the walk ended, which is exactly where there is
/// most likely to be no signal, so a failed upload is not an error to report
/// -- it is a walk to send later. The store records when each walk made it,
/// and anything without that mark is retried the next time the app opens with
/// somebody signed in.
@MainActor
final class WalkUploader {
    /// A backlog is sent newest first and in bounded batches, so reopening the
    /// app after a long spell offline does not turn into a stampede.
    static let backlogLimit = 20

    private let store: WalkStore
    private let sync: WalkSyncing

    private(set) var pendingCount = 0
    var onChange: (() -> Void)?

    init(store: WalkStore, sync: WalkSyncing) {
        self.store = store
        self.sync = sync
    }

    var canUpload: Bool { sync.canUpload }

    /// Sends one walk. Returns false when it did not make it, which is a
    /// normal outcome rather than a failure worth interrupting anyone over.
    @discardableResult
    func upload(_ walk: Walk) async -> Bool {
        guard sync.canUpload else {
            refreshPendingCount()
            return false
        }
        do {
            try await sync.upload(walk)
            try store.markUploaded(walkID: walk.id, at: Date())
            refreshPendingCount()
            return true
        } catch {
            refreshPendingCount()
            return false
        }
    }

    /// Walks that are finished but have never reached the cloud, newest first.
    func pending() -> [WalkMetadata] {
        let walks = (try? store.listWalks()) ?? []
        return walks.filter { !$0.isActive && $0.uploadedAt == nil }
    }

    func refreshPendingCount() {
        pendingCount = pending().count
        onChange?()
    }

    /// Works through the backlog, stopping at the first failure: if one upload
    /// could not go out, the next one will not either.
    func uploadPending() async {
        guard sync.canUpload else {
            refreshPendingCount()
            return
        }
        for metadata in pending().prefix(Self.backlogLimit) {
            guard let walk = try? store.loadWalk(metadata.id), !walk.points.isEmpty else {
                continue
            }
            guard await upload(walk) else { return }
        }
    }
}
