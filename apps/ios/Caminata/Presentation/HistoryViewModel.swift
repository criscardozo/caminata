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
                errorMessage = "Esa caminata no tiene posiciones registradas."
                return
            }
            var ready = try await exporter.export(walk)
            // A walk that reached the cloud can be opened on the web; one that
            // never did would link to a page with nothing to show.
            if metadata.uploadedAt != nil {
                ready.webURL = WebHistory.url(for: walk.id)
            }
            export = ready
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func emailBody(for export: WalkExport) -> String {
        exporter.emailBody(for: export.walk, webURL: export.webURL)
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
                errorMessage = "No se pudo borrar esa caminata de la web. Probá de nuevo con conexión."
            }
        }

        walks.removeAll { removed.contains($0.id) }
    }
}
