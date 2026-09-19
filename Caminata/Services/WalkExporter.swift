import Foundation
import UIKit

struct WalkExport: Identifiable {
    let walk: Walk
    let name: String
    let image: UIImage
    let imageURL: URL
    let gpxURL: URL

    var id: UUID { walk.id }
    var attachments: [URL] { [imageURL, gpxURL] }
}

/// The export step, behind a protocol so the stop path can be exercised in
/// tests without fetching map tiles.
protocol WalkExporting {
    func export(_ walk: Walk) async throws -> WalkExport
    func emailBody(for walk: Walk) -> String
}

/// Turns a finished walk into the two files that get emailed: a map image and
/// a GPX track.
struct WalkExporter: WalkExporting {
    var renderer = MapSnapshotRenderer()
    var fileManager: FileManager = .default

    func export(_ walk: Walk) async throws -> WalkExport {
        let name = WalkFormatting.walkName(startedAt: walk.startedAt)
        let image = try await renderer.render(
            walk: walk,
            caption: WalkFormatting.summaryCaption(for: walk)
        )

        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("CaminataExports/\(walk.id.uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let stamp = WalkFormatting.fileStamp(walk.startedAt)
        let imageURL = directory.appendingPathComponent("walk-\(stamp).png")
        let gpxURL = directory.appendingPathComponent("walk-\(stamp).gpx")

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

    func emailBody(for walk: Walk) -> String {
        let stats = walk.stats
        return """
        \(WalkFormatting.walkName(startedAt: walk.startedAt))

        Distance: \(WalkFormatting.distance(stats.distance))
        Duration: \(WalkFormatting.duration(stats.elapsed))
        Moving time: \(WalkFormatting.duration(stats.movingTime))
        Average pace: \(WalkFormatting.pace(stats.averagePace))
        Elevation gain: \(WalkFormatting.elevation(stats.elevationGain))

        The map image and the GPX track are attached.
        """
    }
}
