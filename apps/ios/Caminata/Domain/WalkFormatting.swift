import Foundation

enum WalkFormatting {
    static func distance(_ metres: Double) -> String { LiveFormat.distance(metres) }

    static func duration(_ interval: TimeInterval) -> String { LiveFormat.duration(interval) }

    static func pace(_ secondsPerKilometre: TimeInterval?) -> String { LiveFormat.pace(secondsPerKilometre) }

    static func elevation(_ metres: Double) -> String {
        String(format: "%.0f m", metres)
    }

    /// The name to show: whatever the walk is called, falling back to when it
    /// happened.
    static func displayName(for metadata: WalkMetadata) -> String {
        let trimmed = metadata.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, !trimmed.isEmpty { return trimmed }
        return walkName(startedAt: metadata.startedAt)
    }

    static func walkName(startedAt: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Caminata del \(formatter.string(from: startedAt))"
    }

    static func fileStamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter.string(from: date)
    }

    static func summaryCaption(for walk: Walk) -> String {
        let stats = walk.stats
        return [
            displayName(for: walk.metadata),
            distance(stats.distance),
            duration(stats.elapsed),
            pace(stats.averagePace)
        ].joined(separator: "  ·  ")
    }
}
