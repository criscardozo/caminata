import SwiftUI

extension Color {
    /// The route colour as the app stores it, `#RRGGBB`. SwiftUI only, so the
    /// widget extension and the watch can use it without UIKit.
    init(hex: String, fallback: Color = Color(red: 0.85, green: 0.16, blue: 0.24)) {
        var digits = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if digits.hasPrefix("#") { digits.removeFirst() }
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else {
            self = fallback
            return
        }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
