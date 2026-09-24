import Foundation

enum WalkFormatting {
    static func distance(_ metres: Double) -> String {
        if metres < 1000 {
            return String(format: "%.0f m", metres)
        }
        return String(format: "%.2f km", metres / 1000)
    }

    static func duration(_ interval: TimeInterval) -> String {
        let total = Int(interval.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Pace reads as min/km, the unit people actually walk by.
    static func pace(_ secondsPerKilometre: TimeInterval?) -> String {
        guard let secondsPerKilometre else { return "--" }
        let total = Int(secondsPerKilometre.rounded())
        return String(format: "%d:%02d /km", total / 60, total % 60)
    }

    static func elevation(_ metres: Double) -> String {
        String(format: "%.0f m", metres)
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
            walkName(startedAt: walk.startedAt),
            distance(stats.distance),
            duration(stats.elapsed),
            pace(stats.averagePace)
        ].joined(separator: "  ·  ")
    }
}
