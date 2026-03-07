import SwiftUI

extension Color {
    // Light Mode (UX Brief + Apple Layering)
    static let appBackground = Color(hex: "F4F7F8")
    static let backgroundSecondary = Color(hex: "EBF0F2")
    static let surfacePrimary = Color(hex: "FFFFFF")
    static let surfaceSecondary = Color(hex: "F9FAFB")
    static let surfaceTertiary = Color(hex: "F0F2F5") // For Modals

    static let textPrimary = Color(hex: "17222A")
    static let textSecondary = Color(hex: "4E626E")
    
    // Risk Levels (Semantic)
    static let lowRisk = Color(hex: "2ECC71")
    static let mediumRisk = Color(hex: "F39C12")
    static let highRisk = Color(hex: "E74C3C")
    
    // Accent
    static let accent = Color(hex: "3498DB")
    static let accentDark = Color(hex: "2E86C1")
    
    // Premium Gradients
    static let brandGradient = LinearGradient(
        colors: [Color(hex: "3498DB"), Color(hex: "5DADE2")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let warningGradient = LinearGradient(
        colors: [Color(hex: "F39C12"), Color(hex: "F5B041")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let dangerGradient = LinearGradient(
        colors: [Color(hex: "E74C3C"), Color(hex: "EC7063")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let meshBackground = Color(hex: "0F1418")
    
    // Semantic System Overrides for Dark Mode (Apple Adaptive)
    static var adaptiveBackground: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(hex: "0A0E12") : UIColor(hex: "F4F7F8")
        })
    }
    
    static var adaptiveSurface: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(hex: "151D24") : UIColor(hex: "FFFFFF")
        })
    }
}

// UIKit extension for Hex
extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, alpha: Double(a) / 255)
    }
}

// Helper for Hex initialization
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    init(light: String, dark: String) {
        self.init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}
