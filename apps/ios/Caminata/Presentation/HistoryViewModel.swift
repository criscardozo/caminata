import Foundation
import Observation

@MainActor
@Observable
final class HistoryViewModel {
    private(set) var walks: [WalkMetadata] = []
    private(set) var isExporting = false
    var export: WalkExport?
    var errorMessage: String?

    private let store: WalkStore
    private let exporter: WalkExporting
    private let uploader: WalkUploader?

    init(store: WalkStore, exporter: WalkExporting, uploader: WalkUploader? = nil) {
        self.store = store
        self.exporter = exporter
        self.uploader = uploader
    }

    func load() {
        do {
            walks = try store.listWalks().filter { !$0.isActive }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func open(_ metadata: WalkMetadata) async {
        isExporting = true
        defer { isExporting = false }
        do {
            let walk = try store.loadWalk(metadata.id)
            guard !walk.points.isEmpty else {
                errorMessage = "That walk has no recorded positions."
                return
            }
            export = try await exporter.export(walk)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func emailBody(for walk: Walk) -> String {
        exporter.emailBody(for: walk)
    }

    /// Deleting has to reach the cloud copy too, or a walk removed on the
    /// phone would sit on the web forever with nothing left to remove it.
    func delete(at offsets: IndexSet) async {
        var removed: [UUID] = []

        for metadata in offsets.map({ walks[$0] }) {
            do {
                if let uploader {
                    try await uploader.delete(metadata)
                } else {
                    try store.delete(walkID: metadata.id)
                }
                removed.append(metadata.id)
            } catch {
                errorMessage = "Could not delete that walk from the web. Try again with a connection."
            }
        }

        walks.removeAll { removed.contains($0.id) }
    }
}
