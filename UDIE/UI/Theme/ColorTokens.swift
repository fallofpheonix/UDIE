import SwiftUI

enum ColorTokens {
    static let mapFadeTop = Color.white.opacity(0.06)
    static let mapFadeBottom = Color.black.opacity(0.24)

    static let appBackground = Color(white: 0.97)
    static let cardSurface = Color.white.opacity(0.88)
    static let cardStroke = Color.black.opacity(0.08)

    static let lowRisk = Color(hex: "34C759")
    static let mediumRisk = Color(hex: "FF9F0A")
    static let highRisk = Color(hex: "FF3B30")

    static let neutralPrimary = Color(hex: "2F4858")
    static let neutralAccent = Color(hex: "6FA3A9")
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch cleaned.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
