import Foundation
import Observation

@Observable
final class HistoryViewModel {
    private(set) var walks: [WalkMetadata] = []
    private(set) var isExporting = false
    var export: WalkExport?
    var errorMessage: String?

    private let store: WalkStore
    private let exporter: WalkExporter

    init(store: WalkStore, exporter: WalkExporter) {
        self.store = store
        self.exporter = exporter
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

    func delete(at offsets: IndexSet) {
        for index in offsets {
            let walk = walks[index]
            do {
                try store.delete(walkID: walk.id)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        walks.remove(atOffsets: offsets)
    }
}
