import Foundation

/// The three figures every screen shows, formatted one way everywhere: the
/// phone, the lock screen and the watch.
enum LiveFormat {
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
}
