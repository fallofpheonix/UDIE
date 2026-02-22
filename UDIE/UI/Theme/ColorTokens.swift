import SwiftUI
import UIKit

enum ColorTokens {
    static let mapFadeTop = Color(light: "FFFFFF", dark: "0F1418").opacity(0.08)
    static let mapFadeBottom = Color(light: "D8E0E5", dark: "12181D").opacity(0.42)
    static let mapOverlaySoft = Color(light: "EDF2F5", dark: "141B20").opacity(0.52)

    static let appBackground = Color(light: "F4F7F8", dark: "1C2328")
    static let surfacePrimary = Color(light: "FFFFFF", dark: "222A30")
    static let surfaceSecondary = Color(light: "EEF3F5", dark: "28323A")
    static let cardSurface = surfacePrimary
    static let cardStroke = Color(light: "D8E0E5", dark: "3A4650")
    static let surfaceTintedA = Color(light: "EAF3F1", dark: "263833")
    static let surfaceTintedB = Color(light: "F2EEF8", dark: "352E3D")
    static let surfaceTintedC = Color(light: "F8F1E8", dark: "3B3428")

    static let lowRisk = Color(hex: "34C759")
    static let mediumRisk = Color(hex: "FF9F0A")
    static let highRisk = Color(hex: "FF3B30")

    static let neutralPrimary = Color(hex: "2F4858")
    static let neutralAccent = Color(hex: "6FA3A9")
    static let textPrimary = Color(light: "17222A", dark: "E7EEF3")
    static let textSecondary = Color(light: "4E626E", dark: "9FB0BA")
    static let controlFill = Color(light: "F0F4F6", dark: "2C373F")
    static let chipBackground = Color(light: "E7EFF2", dark: "2B3740")
}

extension Color {
    init(light: String, dark: String) {
        self.init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }

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

private extension UIColor {
    convenience init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)

        let r = CGFloat((int >> 16) & 0xFF) / 255.0
        let g = CGFloat((int >> 8) & 0xFF) / 255.0
        let b = CGFloat(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
