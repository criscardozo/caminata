import Foundation

enum GPXExporter {
    static func gpx(for walk: Walk, name: String) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Caminata" xmlns="http://www.topografix.com/GPX/1/1">
          <metadata>
            <name>\(escape(name))</name>
            <time>\(timestamp(walk.startedAt))</time>
          </metadata>
          <trk>
            <name>\(escape(name))</name>
            <trkseg>

        """

        for point in walk.points {
            xml += """
                  <trkpt lat="\(coordinate(point.coordinate.latitude))" lon="\(coordinate(point.coordinate.longitude))">
                    <ele>\(elevation(point.altitude))</ele>
                    <time>\(timestamp(point.timestamp))</time>
                  </trkpt>

            """
        }

        xml += """
            </trkseg>
          </trk>
        </gpx>

        """
        return xml
    }

    /// Date formatters are thread-safe once configured, and building one per
    /// timestamp would dominate the cost of exporting a long walk.
    nonisolated(unsafe) private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    private static func timestamp(_ date: Date) -> String {
        formatter.string(from: date)
    }

    private static func coordinate(_ value: Double) -> String {
        String(format: "%.7f", value)
    }

    private static func elevation(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
