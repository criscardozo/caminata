import Foundation
import UIKit

struct WalkExport: Identifiable {
    let walk: Walk
    let name: String
    let image: UIImage
    let imageURL: URL
    let gpxURL: URL

    /// Set once the walk is known to be in the cloud, because a link to a walk
    /// that never got there opens a page that cannot show it.
    var webURL: URL?

    var id: UUID { walk.id }
    var attachments: [URL] { [imageURL, gpxURL] }
}

/// The export step, behind a protocol so the stop path can be exercised in
/// tests without fetching map tiles.
@MainActor
protocol WalkExporting {
    func export(_ walk: Walk) async throws -> WalkExport
    func emailBody(for walk: Walk, webURL: URL?) -> String
}

/// Turns a finished walk into the two files that get emailed: a map image and
/// a GPX track.
struct WalkExporter: WalkExporting {
    var renderer = MapSnapshotRenderer()
    var fileManager: FileManager = .default
    var settings: AppSettings

    func export(_ walk: Walk) async throws -> WalkExport {
        let name = WalkFormatting.displayName(for: walk.metadata)
        var renderer = renderer
        renderer.style.routeColor = RouteColor.uiColor(from: settings.routeColorHex)

        let image = try await renderer.render(
            walk: walk,
            caption: settings.captionOnImage ? WalkFormatting.summaryCaption(for: walk) : nil
        )

        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("CaminataExports/\(walk.id.uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let stamp = WalkFormatting.fileStamp(walk.startedAt)
        let imageURL = directory.appendingPathComponent("caminata-\(stamp).png")
        let gpxURL = directory.appendingPathComponent("caminata-\(stamp).gpx")

        guard let png = image.pngData() else {
            throw CocoaError(.fileWriteUnknown)
        }
        try png.write(to: imageURL, options: .atomic)
        try Data(GPXExporter.gpx(for: walk, name: name).utf8)
            .write(to: gpxURL, options: .atomic)

        return WalkExport(
            walk: walk,
            name: name,
            image: image,
            imageURL: imageURL,
            gpxURL: gpxURL
        )
    }

    func emailBody(for walk: Walk, webURL: URL? = nil) -> String {
        let stats = walk.stats
        var body = """
        \(WalkFormatting.displayName(for: walk.metadata))

        Distancia: \(WalkFormatting.distance(stats.distance))
        Duración: \(WalkFormatting.duration(stats.elapsed))
        En movimiento: \(WalkFormatting.duration(stats.movingTime))
        Ritmo promedio: \(WalkFormatting.pace(stats.averagePace))
        Desnivel acumulado: \(WalkFormatting.elevation(stats.elevationGain))

        Van adjuntos la imagen del mapa y el track GPX.
        """

        if let webURL {
            body += "\n\nVerla en la web: \(webURL.absoluteString)"
        }
        return body
    }
}
