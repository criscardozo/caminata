import SwiftUI

/// The colour of a drawn route, stored as a hex string so it survives in
/// UserDefaults and travels to the web in the walk document.
enum RouteColor {
    /// The red the app has always drawn with.
    static let `default` = "#D9293D"

    /// A small set worth offering, all of them legible over map tiles.
    static let presets = ["#D9293D", "#F2760C", "#0E9F6E", "#2563EB", "#7C3AED", "#111827"]

    static func hex(from color: Color) -> String {
        let components = UIColor(color).cgColor.components ?? []
        guard components.count >= 3 else { return `default` }
        let channels = components.prefix(3).map { Int((max(0, min(1, $0)) * 255).rounded()) }
        return "#" + channels.map { String(format: "%02X", $0) }.joined()
    }

    static func color(from hex: String) -> Color {
        Color(uiColor: uiColor(from: hex))
    }

    static func uiColor(from hex: String) -> UIColor {
        var trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("#") { trimmed.removeFirst() }
        guard trimmed.count == 6, let value = UInt32(trimmed, radix: 16) else {
            return uiColor(from: `default`)
        }
        return UIColor(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }

    /// True for a string this app would have written, so a value arriving from
    /// somewhere else cannot end up in a document or a drawing.
    static func isValid(_ hex: String) -> Bool {
        var trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("#") { trimmed.removeFirst() }
        return trimmed.count == 6 && UInt32(trimmed, radix: 16) != nil
    }
}
